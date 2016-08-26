/* ANTINAT
 * =======
 * This software is Copyright (c) 2004-05 Malcolm Smith.
 * No warranty is provided, including but not limited to
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * This code is licenced subject to the GNU General
 * Public Licence (GPL).  See the COPYING file for more.
 */

#include "an_serv.h"
#ifdef HAVE_STDIO_H
#include <stdio.h>
#endif
#ifdef HAVE_STRING_H
#include <string.h>
#endif
#ifdef HAVE_NETINET_IN_H
#include <netinet/in.h>
#endif
#ifdef HAVE_NETINET_IN6_H
#include <netinet/in6.h>
#endif
#ifdef HAVE_NETINET6_IN_H
#include <netinet6/in.h>
#endif
#ifdef HAVE_ARPA_INET_H
#include <arpa/inet.h>
#endif
#ifdef HAVE_STDLIB_H
#include <stdlib.h>
#endif
#ifdef HAVE_EXPAT_H
#ifdef _WIN32_
#define XML_STATIC
#endif
#include "expat.h"
#endif
#include "fmemopen.h"
#include "project.h"
#include "filters.h"

XML_Parser p;

/*
Structure that records currently open XML tags while parsing.
*/
typedef struct stack {
	void *data;
	struct stack *previous;
	config_t *topconf;
} stack;

/*
Clear structures to default values
*/
static void
config_init_config (config_t * conf)
{
	int i;
	os_mutex_init (&conf->lock);
	conf->refcount = 1;
	conf->auth = NULL;
	conf->filt = NULL;
	conf->intface = INADDR_ANY;
	conf->maxbindwait = 60;
	conf->port = 1080;
	conf->maxconnsperthread = 100;
	conf->usecount = 0;
	conf->throttle = 0;

	conf->allowlocalusers = 0;
	conf->users = NULL;
	conf->chains = NULL;

	conf->sumlog.useConnFile = NULL;

	for (i = 0; i < LOG_MAX; i++) {
		conf->sumlog.useAddrFile[i] = NULL;
		conf->sumlog.useUserFile[i] = NULL;
	}
}

static void
config_init_chain (chain_t * chain)
{
	chain->name = NULL;
	chain->uri = NULL;
	chain->user = NULL;
	chain->pass = NULL;
	chain->authschemes = 0;
	chain->next = NULL;
}

static void
config_init_stack (stack * stk)
{
	stk->data = NULL;
	stk->previous = NULL;
	stk->topconf = NULL;
}

static void
config_init_acnode (ac_nodes * node)
{
	node->action = 0;
	node->alt.select = 0;
	node->alt.branch = NULL;
}

static ac_nodes *
config_new_acnode (authchoice_t * choice)
{
	choice->nnodes++;
	choice->nodes = (ac_nodes *) realloc (choice->nodes,
										  choice->nnodes * sizeof (ac_nodes));
	config_init_acnode (&choice->nodes[choice->nnodes - 1]);
	return &choice->nodes[choice->nnodes - 1];
}

static void
config_init_authchoice (authchoice_t * choice)
{
	choice->source_port = 0;
	choice->source_addrtype = 0;
	choice->source_addr = NULL;

	choice->have_source_port = 0;
	choice->have_source_addrtype = 0;
	choice->have_source_addr = 0;

	choice->have_source_addrtype_inherited = 0;

	choice->nodes = NULL;
	choice->nnodes = 0;
}

static void
config_init_filnode (fil_nodes * node)
{
	node->action = 0;
	node->alt.branch = NULL;
	node->alt.chain = NULL;
}

static fil_nodes *
config_new_filnode (filter_t * filt)
{
	filt->nnodes++;
	filt->nodes = (fil_nodes *) realloc (filt->nodes,
										 filt->nnodes * sizeof (fil_nodes));
	config_init_filnode (&filt->nodes[filt->nnodes - 1]);
	return &filt->nodes[filt->nnodes - 1];
}

static void
config_init_filter (filter_t * filt)
{
	filt->source_port = 0;
	filt->source_addrtype = 0;
	filt->source_addr = NULL;

	filt->have_source_port = 0;
	filt->have_source_addrtype = 0;
	filt->have_source_addr = 0;

	filt->dest_port = 0;
	filt->dest_addrtype = 0;
	filt->dest_addr = NULL;

	filt->have_dest_port = 0;
	filt->have_dest_addrtype = 0;
	filt->have_dest_addr = 0;

	filt->have_source_addrtype_inherited = 0;
	filt->have_dest_addrtype_inherited = 0;

	filt->version = 0;
	filt->user = NULL;
	filt->authscheme = 0;
	filt->authsrc = 0;
	filt->socksop = 0;

	filt->have_version = 0;
	filt->have_user = 0;
	filt->have_authscheme = 0;
	filt->have_authsrc = 0;
	filt->have_socksop = 0;

	filt->throttle = 0;
	filt->have_throttle = 0;

	filt->nodes = NULL;
	filt->nnodes = 0;
}


static void
config_parseerror (const char *error)
{
#ifndef _WIN32_
	printf ("PARSE ERROR: %s\n", error);
#else
	MessageBox (NULL, error, "Antinat: PARSE ERROR", 16);
#endif
	exit (EXIT_FAILURE);
}

/*
This function translates between the xml keyword for an address type
and the internal representation, and aborts if it fails.
*/
static int
config_get_addrtype (const char *string)
{
	if (strcmp (string, "ipv4") == 0)
		return AF_INET;
	if (strcmp (string, "ip") == 0)
		return AF_INET;
#ifdef WITH_IPV6
	if (strcmp (string, "ipv6") == 0)
		return AF_INET6;
#endif
	config_parseerror ("unrecognised address type");
	/* Never get here.  Compiler shutup. */
	return -1;
}

/*
This function translates between the xml keyword for an authentication
mechanism and the internal representation, and aborts if it fails.
*/
static int
config_get_authmech (const char *string)
{
	if (strcmp (string, "chap") == 0)
		return 0x03;
	if (strcmp (string, "cleartext") == 0)
		return 0x02;
	if (strcmp (string, "anonymous") == 0)
		return 0x00;
	config_parseerror ("unrecognised authentication type");
	/* Never get here.  Compiler shutup. */
	return -1;
}

/*
This function translates between the xml keyword for an authentication
mechanism and the client library representation, and aborts if it fails.
*/
static int
config_get_authmech_cli (const char *string)
{
	if (strcmp (string, "chap") == 0)
		return AN_AUTH_CHAP;
	if (strcmp (string, "cleartext") == 0)
		return AN_AUTH_CLEARTEXT;
	if (strcmp (string, "anonymous") == 0)
		return AN_AUTH_ANON;
	config_parseerror ("unrecognised authentication type");
	/* Never get here.  Compiler shutup. */
	return -1;
}

/*
This function translates between the xml keyword for an authentication
source and the internal representation, and aborts if it fails.
*/
static int
config_get_authsrc (const char *string)
{
	if (strcmp (string, "anonymous") == 0)
		return AUTH_ANON;
	if (strcmp (string, "local") == 0)
		return AUTH_LOCAL;
	if (strcmp (string, "config") == 0)
		return AUTH_CONFIG;
	config_parseerror ("unrecognised authentication source");
	/* Never get here.  Compiler shutup. */
	return -1;
}

/*
This function translates between the xml keyword for a SOCKS
operation and the internal representation, and aborts if it fails.
*/
static int
config_get_socksop (const char *string)
{
	if (strcmp (string, "connect") == 0)
		return 0x01;
	if (strcmp (string, "bind") == 0)
		return 0x02;
	if (strcmp (string, "udp") == 0)
		return 0x03;
	if (strcmp (string, "ident") == 0)
		return 0x88;
	config_parseerror ("unrecognised SOCKS operation");
	/* Never get here.  Compiler shutup. */
	return -1;
}

/*
This function parses the XML representation of an address into an
internal representation of that address.
*/
static unsigned char *
config_get_addr (int addrtype, const char *string)
{
	unsigned char *ret;
	char *bitmask;
	int i;
	unsigned int mask;
	int nmask;
	switch (addrtype) {
	case AF_INET:
		ret = (unsigned char *) malloc (16);

		/* If the address has a /, it also has a bitmask */
		bitmask = strchr (string, '/');
		if (bitmask) {
			nmask = atoi (bitmask + 1);
		} else {
			nmask = 32;
		}

		/* Calculate the binary form of the mask now, don't do it
		   for every connection */
		mask = 0;
		for (i = 0; i < nmask; i++)
			mask = (mask << 1) + 1;
		for (; i < 32; i++)
			mask = mask << 1;

		/* Return the mask as the first four bytes */
		memcpy (ret, &mask, 4);

		/* Now the address itself */
		mask = 0;
		bitmask = (char *) string;
		for (i = 0; i < 4; i++) {
			mask = mask * 256 + atoi (bitmask);
			bitmask = strchr (bitmask, '.');
			bitmask++;
		}
		memcpy (ret + 4, &mask, 4);
		return ret;
		break;
#ifdef WITH_IPV6
	case AF_INET6:
/* FIXME: Add IPv6 filtration */
		config_parseerror ("IPv6 addresses not currently supported");
		break;
#endif
	default:
		config_parseerror ("addresses cannot be specified for this type");
	}
	/* Never get here, compiler shutup */
	return NULL;
}

void config_xml_start (void *, const char *, const char **);
void config_xml_end (void *, const char *);

void
config_ac_start (void *data, const char *name, const char **atts)
{
	BOOL handled = FALSE;
	BOOL handledatt = FALSE;
	ac_nodes *node;
	int i;
	stack *stk = (stack *) data;
#ifdef WITH_DEBUG
	char szDebug[300];
	sprintf (szDebug, "Loading tag %s", name);
	DEBUG_LOG (szDebug);
#endif
	if (strcmp (name, "authchoice") == 0) {
		stack *newstk;
		authchoice_t *choice;
		handled = TRUE;

		choice = (authchoice_t *) malloc (sizeof (authchoice_t));
		config_init_authchoice (choice);

		if (stk->data == NULL) {
			newstk = stk;
			newstk->topconf->auth = choice;
		} else {
			authchoice_t *previouschoice;
			newstk = (stack *) malloc (sizeof (stack));
			config_init_stack (newstk);
			newstk->previous = stk;
			newstk->topconf = stk->topconf;
			previouschoice = (authchoice_t *) stk->data;
			choice->have_source_addrtype_inherited =
				previouschoice->have_source_addrtype_inherited;
			choice->source_addrtype = previouschoice->source_addrtype;
		}
		newstk->data = choice;
		for (i = 0; atts[i] && atts[i + 1]; i += 2) {
			if (strcmp (atts[i], "source_addrtype") == 0) {
				if (choice->have_source_addrtype_inherited) {
					config_parseerror
						("Cannot test source_addrtype because test already made");
				}
				handledatt = TRUE;
				choice->source_addrtype = config_get_addrtype (atts[i + 1]);
				choice->have_source_addrtype = 1;
				choice->have_source_addrtype_inherited = 1;
			}
			if (strcmp (atts[i], "source_addr") == 0) {
				handledatt = TRUE;
				if (choice->have_source_addrtype_inherited == 0)
					config_parseerror
						("source_addrtype must preceed source_addr");
				choice->source_addr =
					config_get_addr (choice->source_addrtype, atts[i + 1]);
				choice->have_source_addr = 1;
			}
			if (strcmp (atts[i], "source_port") == 0) {
				handledatt = TRUE;
				choice->source_port = atoi (atts[i + 1]);
				choice->have_source_port = 1;
			}
			if (!handledatt)
				config_parseerror ("attribute not recognised");
		}
		XML_SetUserData (p, newstk);

		/* The first time this function is invoked there's no need to
		 * branch, because we're working with a brand new object anyway.
		 */
		if (stk != newstk) {
			node = config_new_acnode ((authchoice_t *) stk->data);
			node->action = AUTHCHOICE_ACT_BRANCH;
			node->alt.branch = choice;
		}
	}
	if (strcmp (name, "select") == 0) {
		authchoice_t *choice;
		if (stk->data) {
			choice = (authchoice_t *) stk->data;
		} else {
			config_parseerror ("Can't select without an authchoice");
			/* Compiler shutup. */
			return;
		}
		handled = TRUE;

		node = config_new_acnode (choice);
		node->action = AUTHCHOICE_ACT_SELECT;

		for (i = 0; atts[i] && atts[i + 1]; i += 2) {
			if (strcmp (atts[i], "mechanism") == 0) {
				handledatt = TRUE;
				node->alt.select = config_get_authmech (atts[i + 1]);
			}
			if (!handledatt)
				config_parseerror ("attribute not recognised");
		}
	}
	if (!handled)
		config_parseerror ("tag not recognised");
}

void
config_ac_end (void *data, const char *name)
{
	stack *stk = (stack *) data;
	if (strcmp (name, "authchoice") == 0) {
		if (!stk->previous) {
			XML_SetElementHandler (p, config_xml_start, config_xml_end);
			XML_SetUserData (p, stk->topconf);
		} else {
			XML_SetUserData (p, stk->previous);
		}
		free (stk);
	}
}

void
config_ch_start (void *data, const char *name, const char **atts)
{
	BOOL handled = FALSE;
	BOOL handledatt = FALSE;
	int i;
	config_t *conf = (config_t *) data;
#ifdef WITH_DEBUG
	char szDebug[300];
	sprintf (szDebug, "Loading tag %s", name);
	DEBUG_LOG (szDebug);
#endif
	if (strcmp (name, "authscheme") == 0) {
		handled = TRUE;

		for (i = 0; atts[i] && atts[i + 1]; i += 2) {
			if (strcmp (atts[i], "value") == 0) {
				handledatt = TRUE;
				conf->chains->authschemes =
					(1 << config_get_authmech_cli (atts[i + 1])) | conf->
					chains->authschemes;
			}
		}
	}
	if (strcmp (name, "uri") == 0) {
		handled = TRUE;

		for (i = 0; atts[i] && atts[i + 1]; i += 2) {
			if (strcmp (atts[i], "value") == 0) {
				handledatt = TRUE;
				conf->chains->uri = malloc (strlen (atts[i + 1]) + 1);
				strcpy (conf->chains->uri, atts[i + 1]);
			}
		}
	}
	if (strcmp (name, "user") == 0) {
		handled = TRUE;

		for (i = 0; atts[i] && atts[i + 1]; i += 2) {
			if (strcmp (atts[i], "value") == 0) {
				handledatt = TRUE;
				conf->chains->user = malloc (strlen (atts[i + 1]) + 1);
				strcpy (conf->chains->user, atts[i + 1]);
			}
		}
	}
	if (strcmp (name, "password") == 0) {
		handled = TRUE;

		for (i = 0; atts[i] && atts[i + 1]; i += 2) {
			if (strcmp (atts[i], "value") == 0) {
				handledatt = TRUE;
				conf->chains->pass = malloc (strlen (atts[i + 1]) + 1);
				strcpy (conf->chains->pass, atts[i + 1]);
			}
		}
	}
	if (!handledatt)
		config_parseerror ("attribute not recognised");
	if (!handled)
		config_parseerror ("tag not recognised");
}

void
config_ch_end (void *data, const char *name)
{
	if (strcmp (name, "chain") == 0) {
		XML_SetElementHandler (p, config_xml_start, config_xml_end);
	}
}

void
config_fil_start (void *data, const char *name, const char **atts)
{
	BOOL handled = FALSE;
	BOOL handledatt = FALSE;
	fil_nodes *node;
	int i;
	stack *stk = (stack *) data;
#ifdef WITH_DEBUG
	char szDebug[300];
	sprintf (szDebug, "Loading tag %s", name);
	DEBUG_LOG (szDebug);
#endif
	if (strcmp (name, "accept") == 0) {
		filter_t *filt;
		handled = TRUE;
		if (stk->data) {
			filt = (filter_t *) stk->data;
		} else {
			config_parseerror ("Can't accept without a filter");
			/* Compiler shutup. */
			return;
		}

		node = config_new_filnode (filt);
		node->action = FILTER_ACT_ACCEPT;
	}
	if (strcmp (name, "reject") == 0) {
		filter_t *filt;
		handled = TRUE;
		if (stk->data) {
			filt = (filter_t *) stk->data;
		} else {
			config_parseerror ("Can't accept without a filter");
			/* Compiler shutup. */
			return;
		}

		node = config_new_filnode (filt);
		node->action = FILTER_ACT_REJECT;
	}
	if (strcmp (name, "chain") == 0) {
		filter_t *filt;
		chain_t *chain;
		const char *name = NULL;
		handled = TRUE;
		handledatt = FALSE;
		if (stk->data) {
			filt = (filter_t *) stk->data;
		} else {
			config_parseerror ("Can't accept without a filter");
			/* Compiler shutup. */
			return;
		}

		for (i = 0; atts[i] && atts[i + 1]; i += 2) {
			if (strcmp (atts[i], "name") == 0) {
				handledatt = TRUE;
				name = atts[i + 1];
			}
		}

		if (!handledatt) {
			config_parseerror ("Failed to identify name of chain");
			/* Compiler shutup. */
			return;
		}

		for (chain = stk->topconf->chains; chain; chain = chain->next) {
			if (strcmp (chain->name, name) == 0)
				break;
		}

		if (chain == NULL) {
			config_parseerror
				("Tried to reference a chain without declaring it");
			/* Compiler shutup. */
			return;
		}

		node = config_new_filnode (filt);
		node->alt.chain = chain;
		node->action = FILTER_ACT_CHAIN;
	}
	if (strcmp (name, "filter") == 0) {
		stack *newstk;
		filter_t *filt;
		handled = TRUE;

		filt = (filter_t *) malloc (sizeof (filter_t));
		config_init_filter (filt);

		if (stk->data == NULL) {
			newstk = stk;
			newstk->topconf->filt = filt;
		} else {
			filter_t *previousfilt;
			newstk = (stack *) malloc (sizeof (stack));
			config_init_stack (newstk);
			newstk->previous = stk;
			newstk->topconf = stk->topconf;
			previousfilt = (filter_t *) stk->data;
			filt->have_source_addrtype_inherited =
				previousfilt->have_source_addrtype_inherited;
			filt->source_addrtype = previousfilt->source_addrtype;
			filt->have_dest_addrtype_inherited =
				previousfilt->have_dest_addrtype_inherited;
			filt->dest_addrtype = previousfilt->dest_addrtype;
		}
		newstk->data = filt;
		for (i = 0; atts[i] && atts[i + 1]; i += 2) {
			if (strcmp (atts[i], "authscheme") == 0) {
				handledatt = TRUE;
				filt->authscheme = config_get_authmech (atts[i + 1]);
				filt->have_authscheme = 1;
			}
			if (strcmp (atts[i], "authsrc") == 0) {
				handledatt = TRUE;
				filt->authsrc = config_get_authsrc (atts[i + 1]);
				filt->have_authsrc = 1;
			}
			if (strcmp (atts[i], "dest_addrtype") == 0) {
				if (filt->have_dest_addrtype_inherited) {
					config_parseerror
						("Cannot test dest_addrtype because test already made");
				}
				handledatt = TRUE;
				filt->dest_addrtype = config_get_addrtype (atts[i + 1]);
				filt->have_dest_addrtype = 1;
				filt->have_dest_addrtype_inherited = 1;
			}
			if (strcmp (atts[i], "dest_addr") == 0) {
				handledatt = TRUE;
				if (filt->have_dest_addrtype_inherited == 0)
					config_parseerror
						("dest_addrtype must preceed dest_addr");
				filt->dest_addr =
					config_get_addr (filt->dest_addrtype, atts[i + 1]);
				filt->have_dest_addr = 1;
			}
			if (strcmp (atts[i], "dest_port") == 0) {
				handledatt = TRUE;
				filt->dest_port = atoi (atts[i + 1]);
				filt->have_dest_port = 1;
			}
			if (strcmp (atts[i], "throttle") == 0) {
				handledatt = TRUE;
				filt->throttle = atoi (atts[i + 1]);
				filt->have_throttle = 1;
			}
			if (strcmp (atts[i], "socksop") == 0) {
				handledatt = TRUE;
				filt->socksop = config_get_socksop (atts[i + 1]);
				filt->have_socksop = 1;
			}
			if (strcmp (atts[i], "source_addrtype") == 0) {
				if (filt->have_source_addrtype_inherited) {
					config_parseerror
						("Cannot test source_addrtype because test already made");
				}
				handledatt = TRUE;
				filt->source_addrtype = config_get_addrtype (atts[i + 1]);
				filt->have_source_addrtype = 1;
				filt->have_source_addrtype_inherited = 1;
			}
			if (strcmp (atts[i], "source_addr") == 0) {
				handledatt = TRUE;
				if (filt->have_source_addrtype_inherited == 0)
					config_parseerror
						("source_addrtype must preceed source_addr");
				filt->source_addr =
					config_get_addr (filt->source_addrtype, atts[i + 1]);
				filt->have_source_addr = 1;
			}
			if (strcmp (atts[i], "source_port") == 0) {
				handledatt = TRUE;
				filt->source_port = atoi (atts[i + 1]);
				filt->have_source_port = 1;
			}
			if (strcmp (atts[i], "user") == 0) {
				handledatt = TRUE;
				filt->user = (char *) malloc (strlen (atts[i + 1]) + 1);
				strcpy (filt->user, atts[i + 1]);
				filt->have_user = 1;
			}
			if (strcmp (atts[i], "version") == 0) {
				handledatt = TRUE;
				filt->version = atoi (atts[i + 1]);
				filt->have_version = 1;
			}
			if (!handledatt)
				config_parseerror ("attribute not recognised");
		}
		XML_SetUserData (p, newstk);
		/* Only branch if not the first filter */
		if (stk != newstk) {
			node = config_new_filnode ((filter_t *) stk->data);
			node->action = AUTHCHOICE_ACT_BRANCH;
			node->alt.branch = filt;
		}
	}
	if (!handled)
		config_parseerror ("tag not recognised");
}

void
config_fil_end (void *data, const char *name)
{
	stack *stk = (stack *) data;
	if (strcmp (name, "filter") == 0) {
		if (!stk->previous) {
			XML_SetElementHandler (p, config_xml_start, config_xml_end);
			XML_SetUserData (p, stk->topconf);
		} else {
			XML_SetUserData (p, stk->previous);
		}
		free (stk);
	}
}

void
config_sl_start (void *data, const char *name, const char **atts)
{
	config_t *conf = (config_t *) data;
	BOOL handled = FALSE;
	int i;
#ifdef WITH_DEBUG
	char szDebug[300];
	sprintf (szDebug, "Loading tag %s", name);
	DEBUG_LOG (szDebug);
#endif
	if (strcmp (name, "log") == 0) {
		handled = TRUE;
	}
	/* FIXME: Check for duplicates */
	if (strcmp (name, "connlog") == 0) {
		handled = TRUE;
		for (i = 0; atts[i] && atts[i + 1]; i += 2) {
			if (strcmp (atts[i], "value") == 0) {
				conf->sumlog.useConnFile =
					(char *) malloc (strlen (atts[i + 1]) + 1);
				strcpy (conf->sumlog.useConnFile, atts[i + 1]);
			}
		}
	}
	if (strcmp (name, "addrmonthlog") == 0) {
		handled = TRUE;
		for (i = 0; atts[i] && atts[i + 1]; i += 2) {
			if (strcmp (atts[i], "value") == 0) {
				conf->sumlog.useAddrFile[LOG_MONTH] =
					(char *) malloc (strlen (atts[i + 1]) + 1);
				strcpy (conf->sumlog.useAddrFile[LOG_MONTH], atts[i + 1]);
			}
		}
	}
	if (strcmp (name, "addrdaylog") == 0) {
		handled = TRUE;
		for (i = 0; atts[i] && atts[i + 1]; i += 2) {
			if (strcmp (atts[i], "value") == 0) {
				conf->sumlog.useAddrFile[LOG_DAY] =
					(char *) malloc (strlen (atts[i + 1]) + 1);
				strcpy (conf->sumlog.useAddrFile[LOG_DAY], atts[i + 1]);
			}
		}
	}
	if (strcmp (name, "addrhourlog") == 0) {
		handled = TRUE;
		for (i = 0; atts[i] && atts[i + 1]; i += 2) {
			if (strcmp (atts[i], "value") == 0) {
				conf->sumlog.useAddrFile[LOG_HOUR] =
					(char *) malloc (strlen (atts[i + 1]) + 1);
				strcpy (conf->sumlog.useAddrFile[LOG_HOUR], atts[i + 1]);
			}
		}
	}
	if (strcmp (name, "addrminutelog") == 0) {
		handled = TRUE;
		for (i = 0; atts[i] && atts[i + 1]; i += 2) {
			if (strcmp (atts[i], "value") == 0) {
				conf->sumlog.useAddrFile[LOG_MINUTE] =
					(char *) malloc (strlen (atts[i + 1]) + 1);
				strcpy (conf->sumlog.useAddrFile[LOG_MINUTE], atts[i + 1]);
			}
		}
	}

	if (strcmp (name, "usermonthlog") == 0) {
		handled = TRUE;
		for (i = 0; atts[i] && atts[i + 1]; i += 2) {
			if (strcmp (atts[i], "value") == 0) {
				conf->sumlog.useUserFile[LOG_MONTH] =
					(char *) malloc (strlen (atts[i + 1]) + 1);
				strcpy (conf->sumlog.useUserFile[LOG_MONTH], atts[i + 1]);
			}
		}
	}
	if (strcmp (name, "userdaylog") == 0) {
		handled = TRUE;
		for (i = 0; atts[i] && atts[i + 1]; i += 2) {
			if (strcmp (atts[i], "value") == 0) {
				conf->sumlog.useUserFile[LOG_DAY] =
					(char *) malloc (strlen (atts[i + 1]) + 1);
				strcpy (conf->sumlog.useUserFile[LOG_DAY], atts[i + 1]);
			}
		}
	}
	if (strcmp (name, "userhourlog") == 0) {
		handled = TRUE;
		for (i = 0; atts[i] && atts[i + 1]; i += 2) {
			if (strcmp (atts[i], "value") == 0) {
				conf->sumlog.useUserFile[LOG_HOUR] =
					(char *) malloc (strlen (atts[i + 1]) + 1);
				strcpy (conf->sumlog.useUserFile[LOG_HOUR], atts[i + 1]);
			}
		}
	}
	if (strcmp (name, "userminutelog") == 0) {
		handled = TRUE;
		for (i = 0; atts[i] && atts[i + 1]; i += 2) {
			if (strcmp (atts[i], "value") == 0) {
				conf->sumlog.useUserFile[LOG_MINUTE] =
					(char *) malloc (strlen (atts[i + 1]) + 1);
				strcpy (conf->sumlog.useUserFile[LOG_MINUTE], atts[i + 1]);
			}
		}
	}

	if (!handled)
		config_parseerror ("tag not recognised");
}

void
config_sl_end (void *data, const char *name)
{
	if (strcmp (name, "log") == 0) {
		XML_SetElementHandler (p, config_xml_start, config_xml_end);
	}
}

static void
config_adduser (config_t * conf, const char *user, const char *pass)
{
	char *passtmp;
	char *usertmp;
	if (!conf->users) {
		conf->users = (DSHashTable *) malloc (sizeof (DSHashTable));
		ds_hash_init (conf->users, 500, DEF_PRIMEA, DEF_PRIMEB);
	}
	passtmp = (char *) malloc (strlen (pass) + 1);
	strcpy (passtmp, pass);
	usertmp = (char *) malloc (strlen (user) + 1);
	strcpy (usertmp, user);
	ds_hash_insert_ss (conf->users, (char *) usertmp, passtmp,
					   CLEANUP_KEY_FREE | CLEANUP_VALUE_FREE);
}


void
config_xml_start (void *data, const char *name, const char **atts)
{
	config_t *conf = (config_t *) data;
	int i;
	BOOL handled = FALSE;
	BOOL handledatt = FALSE;
#ifdef WITH_DEBUG
	char szDebug[300];
	sprintf (szDebug, "Loading tag %s", name);
	DEBUG_LOG (szDebug);
#endif
	if (strcmp (name, "antinatconfig") == 0) {
		handled = TRUE;
		handledatt = TRUE;
	}
	if (strcmp (name, "allowlocalusers") == 0) {
		handled = handledatt = TRUE;
		conf->allowlocalusers = TRUE;
		return;
	}
	if (strcmp (name, "authchoice") == 0) {
		stack *newstk;
		handled = TRUE;
		newstk = (stack *) malloc (sizeof (stack));
		config_init_stack (newstk);
		newstk->topconf = conf;
		XML_SetElementHandler (p, config_ac_start, config_ac_end);
		XML_SetUserData (p, newstk);
		config_ac_start (newstk, name, atts);
		return;
	}
	if (strcmp (name, "chain") == 0) {
		chain_t *newchain;
		handled = TRUE;
		newchain = (chain_t *) malloc (sizeof (chain_t));
		config_init_chain (newchain);
		newchain->next = conf->chains;
		conf->chains = newchain;

		for (i = 0; atts[i] && atts[i + 1]; i += 2) {
			if (strcmp (atts[i], "name") == 0) {
				handledatt = TRUE;
				newchain->name = malloc (strlen (atts[i + 1]) + 1);
				strcpy (newchain->name, atts[i + 1]);
			}
		}
		if (!handledatt) {
			config_parseerror ("Attempt to declare a chain without a name");
			return;
		}
		XML_SetElementHandler (p, config_ch_start, config_ch_end);
		return;
	}
	if (strcmp (name, "filter") == 0) {
		stack *newstk;
		handled = TRUE;
		newstk = (stack *) malloc (sizeof (stack));
		config_init_stack (newstk);
		newstk->topconf = conf;
		XML_SetElementHandler (p, config_fil_start, config_fil_end);
		XML_SetUserData (p, newstk);
		config_fil_start (newstk, name, atts);
		return;
	}
	if (strcmp (name, "interface") == 0) {
		handled = TRUE;
		for (i = 0; atts[i] && atts[i + 1]; i += 2) {
			if (strcmp (atts[i], "value") == 0) {
				handledatt = TRUE;
				conf->intface = inet_addr (atts[i + 1]);
			}
		}
	}
	if (strcmp (name, "maxbindwait") == 0) {
		handled = TRUE;
		for (i = 0; atts[i] && atts[i + 1]; i += 2) {
			if (strcmp (atts[i], "value") == 0) {
				handledatt = TRUE;
				conf->maxbindwait = atoi (atts[i + 1]);
			}
		}
	}
	if (strcmp (name, "maxconnsperthread") == 0) {
		handled = TRUE;
		for (i = 0; atts[i] && atts[i + 1]; i += 2) {
			if (strcmp (atts[i], "value") == 0) {
				handledatt = TRUE;
				conf->maxconnsperthread = atoi (atts[i + 1]);
			}
		}
	}
	if (strcmp (name, "port") == 0) {
		handled = TRUE;
		for (i = 0; atts[i] && atts[i + 1]; i += 2) {
			if (strcmp (atts[i], "value") == 0) {
				handledatt = TRUE;
				conf->port = atoi (atts[i + 1]);
			}
		}
	}
	if (strcmp (name, "throttle") == 0) {
		handled = TRUE;
		for (i = 0; atts[i] && atts[i + 1]; i += 2) {
			if (strcmp (atts[i], "value") == 0) {
				handledatt = TRUE;
				conf->throttle = atoi (atts[i + 1]);
			}
		}
	}
	if (strcmp (name, "log") == 0) {
		handled = TRUE;
		XML_SetElementHandler (p, config_sl_start, config_sl_end);
		config_sl_start (data, name, atts);
		return;
	}
	if (strcmp (name, "user") == 0) {
		const char *user = NULL;
		const char *pass = NULL;
		handled = TRUE;
		for (i = 0; atts[i] && atts[i + 1]; i += 2) {
			if (strcmp (atts[i], "user") == 0) {
				user = atts[i + 1];
			}
			if (strcmp (atts[i], "password") == 0) {
				pass = atts[i + 1];
			}
		}
		if (user && pass) {
			handledatt = TRUE;
			config_adduser (conf, user, pass);
		}
	}
	if (!handled)
		config_parseerror ("tag not recognised");
	if (!handledatt)
		config_parseerror ("attribute not recognised");
}

void
config_xml_end (void *data, const char *name)
{
}

BOOL
loadconfig (config_t * currentconfig, const char *config_content, int config_content_size)
{
    FILE *fp;
    char *contents;
    unsigned int len = config_content_size;
    
    config_init_config (currentconfig);
    if (currentconfig)
        fp = fmemopen(config_content, len, "r");
    else
        return FALSE;
    if (!fp)
        return FALSE;
    
    contents = (char *) malloc (config_content_size);
    if (contents == NULL) {
        fclose (fp);
        return FALSE;
    }
    if (fread (contents, 1, len, fp) == 0) {
        free (contents);
        fclose (fp);
        return FALSE;
    }
    fclose (fp);

	p = XML_ParserCreate (NULL);

	XML_SetElementHandler (p, config_xml_start, config_xml_end);
	XML_SetUserData (p, currentconfig);

	XML_Parse (p, contents, len, 1);
	XML_ParserFree (p);

	free (contents);

	return TRUE;
}

/* loc: 0==source, 1==dest */
static BOOL
config_isinaddr (int addrtype, unsigned char *addr, conn_t * conn, int loc)
{
	unsigned long ip;
	unsigned long *nodeip;
	unsigned long *nodemask;
	char *addrtmp;
	switch (addrtype) {
	case AF_INET:
		switch (loc) {
		case 0:
			addrtmp = conn->source.address;
			break;
		case 1:
			addrtmp = conn->dest.address;
			break;
		default:
			return FALSE;
		}
		/* FIXME? */
		memcpy (&ip, addrtmp, 4);
		ip = ntohl (ip);
		nodemask = (unsigned long *) addr;
		nodeip = (unsigned long *) (unsigned char *) (addr + 4);
		if ((ip & *nodemask) != (*nodeip & *nodemask)) {
			return FALSE;
		}
		return TRUE;
		break;
/* FIXME: IPv6 support */
	}
/* FIXME: What else should I do? */
	return FALSE;
}


static unsigned char
config_choosemethod_root (authchoice_t * root,
						  conn_t * conn, unsigned char *meths, int nmeths)
{
	BOOL match = TRUE;
	if (root->have_source_addrtype)
		if (conn->source.address_type != root->source_addrtype)
			match = FALSE;
	if (root->have_source_port)
		if (ntohs ((unsigned short) conn->source.port) != root->source_port)
			match = FALSE;
	if (root->have_source_addr)
		if (!config_isinaddr
			(root->source_addrtype, root->source_addr, conn, 0))
			match = FALSE;
	if (match == TRUE) {
		int i, j;
		unsigned char ret;
		ac_nodes *currentnode;
		for (i = 0; i < root->nnodes; i++) {
			currentnode = &root->nodes[i];
			if (currentnode->action == AUTHCHOICE_ACT_BRANCH) {
				ret = config_choosemethod_root (currentnode->alt.branch,
												conn, meths, nmeths);
				if (ret != 0xff)
					return ret;
			}
			if (currentnode->action == AUTHCHOICE_ACT_SELECT)
				for (j = 0; j < nmeths; j++)
					if (meths[j] == currentnode->alt.select)
						return meths[j];
		}
	} else
		match = TRUE;
	return 0xff;
}

unsigned char
config_choosemethod (config_t * conf, conn_t * conn, unsigned char *meths,
					 int nmeths)
{
	return config_choosemethod_root (conf->auth, conn, meths, nmeths);
}

static int
config_isallowed_root (filter_t * root, conn_t * conn, chain_t ** chain)
{
	BOOL match = TRUE;
	if (root->have_source_addrtype)
		if (conn->source.address_type != root->source_addrtype)
			match = FALSE;
	if (root->have_source_port)
		if (ntohs ((unsigned short) conn->source.port) != root->source_port)
			match = FALSE;
	if (root->have_source_addr)
		if (!config_isinaddr
			(root->source_addrtype, root->source_addr, conn, 0))
			match = FALSE;

	if (root->have_dest_addrtype)
		if (conn->dest.address_type != root->dest_addrtype)
			match = FALSE;
	if (root->have_dest_port)
		if (ntohs ((unsigned short) conn->dest.port) != root->dest_port)
			match = FALSE;
	if (root->have_dest_addr)
		if (!config_isinaddr (root->dest_addrtype, root->dest_addr, conn, 1))
			match = FALSE;

	if (root->have_version)
		if (conn->version != root->version)
			match = FALSE;
	if (root->have_user) {
		char *currentUser;
		currentUser = conn->user;
		if (currentUser == NULL)
			currentUser = "";
		if (strcmp (currentUser, root->user) != 0)
			match = FALSE;
	}
	if (root->have_authscheme)
		if (conn->authscheme != root->authscheme)
			match = FALSE;
	if (root->have_authsrc)
		if (conn->authsrc != root->authsrc)
			match = FALSE;
	if (root->have_socksop)
		if (conn->socksop != root->socksop)
			match = FALSE;
    
	if (match == TRUE) {
		int i;
		int ret;
		fil_nodes *currentnode;
		if (root->have_throttle)
			conn->throttle = root->throttle;
		for (i = 0; i < root->nnodes; i++) {
			currentnode = &root->nodes[i];
			if (currentnode->action == FILTER_ACT_BRANCH) {
				ret =
					config_isallowed_root (currentnode->alt.branch, conn,
										   chain);
				if (ret > 0)
					return ret;
			}
			if (currentnode->action == FILTER_ACT_ACCEPT)
				return 1;
			if (currentnode->action == FILTER_ACT_REJECT)
				return 2;
			if (currentnode->action == FILTER_ACT_CHAIN) {
				*chain = currentnode->alt.chain;
				return 3;
			}
		}
	} else
		match = TRUE;
	return 0;
}

BOOL
config_isallowed (config_t * conf, conn_t * conn, chain_t ** chain)
{
	int ret;
#ifdef WITH_DEBUG
	char szDebug[300];
#endif
	conn->throttle = conf->throttle;
	ret = config_isallowed_root (conf->filt, conn, chain);
	if (ret != 3) {
		*chain = NULL;
	}
#ifdef WITH_DEBUG
	sprintf (szDebug, "Filter reports: %i (chain %p)", ret, (void *) *chain);
	DEBUG_LOG (szDebug);
#endif
    if (ret == 1) {
        // GEOIP
        unsigned long ip;
        char *addrtmp = conn->dest.address;
        memcpy (&ip, addrtmp, 4);

        if (conn->dest.address_type != AF_INET)
        {
            // IPV6
            return TRUE;
        }
        struct sockaddr_in sin;
        memset(&sin, 0, sizeof(struct sockaddr_in));
        sin.sin_family = AF_INET;
        sin.sin_port = htons(conn->dest.port);
        sin.sin_addr.s_addr = ip;

        struct url_actions *action = forward_ip_routing(&sin);

        enum forward_routing routing = action ? action->routing : ROUTE_NONE;

        if (routing == ROUTE_PROXY && proxy_list) {
            ret = 3;
            *chain = conf->chains;
        }else {
            if (action && routing == ROUTE_BLOCK) {
                ret = 2;
            }else {
                if (routing == ROUTE_DIRECT) {
                    ret = 1;
                }else if (global_mode && proxy_list) {
                    ret = 3;
                    *chain = conf->chains;
                }else {
                    ret = 1;
                }
            }
        }
    }
    
	if (ret == 1 || ret == 3)
		return TRUE;
	/* Not allowed or no info */
	return FALSE;
}

int
config_getMaxbindwait (config_t * conf)
{
	return conf->maxbindwait;
}

int
config_getPort (config_t * conf)
{
	return conf->port;
}

int
config_getMaxConnsPerThread (config_t * conf)
{
	return conf->maxconnsperthread;
}

unsigned int
config_getInterface (config_t * conf)
{
	return conf->intface;
}

char *
config_getAddrLog (config_t * conf, int index)
{
	return conf->sumlog.useAddrFile[index];
}

char *
config_getUserLog (config_t * conf, int index)
{
	return conf->sumlog.useUserFile[index];
}

char *
config_getConnLog (config_t * conf)
{
	return conf->sumlog.useConnFile;
}

char *
config_getUser (config_t * conf, const char *user)
{
	if (!conf->users)
		return NULL;
	return (char *) ds_hash_getPtrValue_s (conf->users, user);

}

BOOL
config_allowLocalUsers (config_t * conf)
{
	return conf->allowlocalusers;
}


static void
config_free_ac (authchoice_t * ac)
{
	ac_nodes *node;
	int i;

	for (i = 0; i < ac->nnodes; i++) {
		node = &ac->nodes[i];
		if (node->action == AUTHCHOICE_ACT_BRANCH)
			config_free_ac (node->alt.branch);
	}
	if (ac->nodes)
		free (ac->nodes);
	if (ac->source_addr)
		free (ac->source_addr);
	free (ac);
}

static void
config_free_filter (filter_t * filt)
{
	fil_nodes *node;
	int i;

	for (i = 0; i < filt->nnodes; i++) {
		node = &filt->nodes[i];
		if (node->action == FILTER_ACT_BRANCH)
			config_free_filter (node->alt.branch);
	}
	if (filt->nodes)
		free (filt->nodes);
	if (filt->source_addr)
		free (filt->source_addr);
	if (filt->dest_addr)
		free (filt->dest_addr);
	if (filt->user)
		free (filt->user);
	free (filt);
}

static void
config_free_chain (chain_t * chain)
{
	if (chain->name)
		free (chain->name);
	if (chain->uri)
		free (chain->uri);
	if (chain->user)
		free (chain->user);
	if (chain->pass)
		free (chain->pass);
	free (chain);
}

void
config_free (config_t * conf)
{
	int i;
	if (conf->users) {
		ds_hash_close (conf->users);
		free (conf->users);
		conf->users = NULL;
	}

	if (conf->auth)
		config_free_ac (conf->auth);
	if (conf->filt)
		config_free_filter (conf->filt);
	if (conf->chains) {
		chain_t *next;
		chain_t *current;
		current = conf->chains;
		for (current = conf->chains; current; current = next) {
			next = current->next;
			config_free_chain (current);
		}
	}

	conf->auth = NULL;
	conf->filt = NULL;
	for (i = 0; i < LOG_MAX; i++) {
		if (conf->sumlog.useAddrFile[i])
			free (conf->sumlog.useAddrFile[i]);
		conf->sumlog.useAddrFile[i] = NULL;
		if (conf->sumlog.useUserFile[i])
			free (conf->sumlog.useUserFile[i]);
		conf->sumlog.useUserFile[i] = NULL;
	}
	if (conf->sumlog.useConnFile)
		free (conf->sumlog.useConnFile);
	conf->sumlog.useConnFile = NULL;
}

void
config_reference (config_t * conf)
{
	os_mutex_lock (&conf->lock);
	conf->refcount++;
	os_mutex_unlock (&conf->lock);
}

void
config_dereference (config_t * conf)
{
#ifdef WITH_DEBUG
	char szDebug[300];
#endif
	os_mutex_lock (&conf->lock);
	conf->refcount--;
	if (conf->refcount == 0) {
		config_free (conf);
		os_mutex_unlock (&conf->lock);

		/* Ok, this happens outside the lock.  But we know
		 * nothing is using it, so it can't hurt. */
		os_mutex_close (&conf->lock);
		free (conf);
#ifdef WITH_DEBUG
		sprintf (szDebug, "Last reference to config %p, now destroyed",
				 (void *) conf);
		DEBUG_LOG (szDebug);
#endif
	} else {
		os_mutex_unlock (&conf->lock);
	}
}
