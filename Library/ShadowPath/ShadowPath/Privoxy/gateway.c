const char gateway_rcs[] = "$Id: gateway.c,v 1.96 2016/01/16 12:30:43 fabiankeil Exp $";
/*********************************************************************
 *
 * File        :  $Source: /cvsroot/ijbswa/current/gateway.c,v $
 *
 * Purpose     :  Contains functions to connect to a server, possibly
 *                using a "forwarder" (i.e. HTTP proxy and/or a SOCKS4
 *                or SOCKS5 proxy).
 *
 * Copyright   :  Written by and Copyright (C) 2001-2009 the
 *                Privoxy team. http://www.privoxy.org/
 *
 *                Based on the Internet Junkbuster originally written
 *                by and Copyright (C) 1997 Anonymous Coders and
 *                Junkbusters Corporation.  http://www.junkbusters.com
 *
 *                This program is free software; you can redistribute it
 *                and/or modify it under the terms of the GNU General
 *                Public License as published by the Free Software
 *                Foundation; either version 2 of the License, or (at
 *                your option) any later version.
 *
 *                This program is distributed in the hope that it will
 *                be useful, but WITHOUT ANY WARRANTY; without even the
 *                implied warranty of MERCHANTABILITY or FITNESS FOR A
 *                PARTICULAR PURPOSE.  See the GNU General Public
 *                License for more details.
 *
 *                The GNU General Public License should be included with
 *                this file.  If not, you can view it at
 *                http://www.gnu.org/copyleft/gpl.html
 *                or write to the Free Software Foundation, Inc., 59
 *                Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 *
 *********************************************************************/


#include "sp_config.h"

#include <stdio.h>
#include <sys/types.h>

#ifndef _WIN32
#include <netinet/in.h>
#endif

#include <errno.h>
#include <string.h>
#include "assert.h"

#ifdef _WIN32
#include <winsock2.h>
#endif /* def _WIN32 */

#ifdef __BEOS__
#include <netdb.h>
#endif /* def __BEOS__ */

#ifdef __OS2__
#include <utils.h>
#endif /* def __OS2__ */

#include "project.h"
#include "jcc.h"
#include "errlog.h"
#include "jbsockets.h"
#include "gateway.h"
#include "miscutil.h"
#include "list.h"
#include "parsers.h"

#ifdef FEATURE_CONNECTION_KEEP_ALIVE
#ifdef HAVE_POLL
#ifdef __GLIBC__
#include <sys/poll.h>
#else
#include <poll.h>
#endif /* def __GLIBC__ */
#endif /* HAVE_POLL */
#endif /* def FEATURE_CONNECTION_KEEP_ALIVE */

const char gateway_h_rcs[] = GATEWAY_H_VERSION;

enum {
   SOCKS4_REQUEST_GRANTED        =  90,
   SOCKS4_REQUEST_REJECT         =  91,
   SOCKS4_REQUEST_IDENT_FAILED   =  92,
   SOCKS4_REQUEST_IDENT_CONFLICT =  93
};

enum {
   SOCKS5_REQUEST_GRANTED             = 0,
   SOCKS5_REQUEST_FAILED              = 1,
   SOCKS5_REQUEST_DENIED              = 2,
   SOCKS5_REQUEST_NETWORK_UNREACHABLE = 3,
   SOCKS5_REQUEST_HOST_UNREACHABLE    = 4,
   SOCKS5_REQUEST_CONNECTION_REFUSED  = 5,
   SOCKS5_REQUEST_TTL_EXPIRED         = 6,
   SOCKS5_REQUEST_PROTOCOL_ERROR      = 7,
   SOCKS5_REQUEST_BAD_ADDRESS_TYPE    = 8
};

/* structure of a socks client operation */
struct socks_op {
   unsigned char vn;          /* socks version number */
   unsigned char cd;          /* command code */
   unsigned char dstport[2];  /* destination port */
   unsigned char dstip[4];    /* destination address */
   char userid;               /* first byte of userid */
   char padding[3];           /* make sure sizeof(struct socks_op) is endian-independent. */
   /* more bytes of the userid follow, terminated by a NULL */
};

/* structure of a socks server reply */
struct socks_reply {
   unsigned char vn;          /* socks version number */
   unsigned char cd;          /* command code */
   unsigned char dstport[2];  /* destination port */
   unsigned char dstip[4];    /* destination address */
};

static const char socks_userid[] = "anonymous";

#ifdef FEATURE_CONNECTION_SHARING

#define MAX_REUSABLE_CONNECTIONS 100
static unsigned int keep_alive_timeout = DEFAULT_KEEP_ALIVE_TIMEOUT;

static struct reusable_connection reusable_connection[MAX_REUSABLE_CONNECTIONS];
static int mark_connection_unused(const struct reusable_connection *connection);

/*********************************************************************
 *
 * Function    :  initialize_reusable_connections
 *
 * Description :  Initializes the reusable_connection structures.
 *                Must be called with connection_reuse_mutex locked.
 *
 * Parameters  : N/A
 *
 * Returns     : void
 *
 *********************************************************************/
extern void initialize_reusable_connections(void)
{
   unsigned int slot = 0;

   for (slot = 0; slot < SZ(reusable_connection); slot++)
   {
      mark_connection_closed(&reusable_connection[slot]);
   }

   log_error(LOG_LEVEL_CONNECT, "Initialized %d socket slots.", slot);
}


/*********************************************************************
 *
 * Function    :  remember_connection
 *
 * Description :  Remembers a server connection for reuse later on.
 *
 * Parameters  :
 *          1  :  connection = The server connection to remember.
 *
 * Returns     : void
 *
 *********************************************************************/
void remember_connection(const struct reusable_connection *connection)
{
   unsigned int slot = 0;
   int free_slot_found = FALSE;

   assert(NULL != connection);
   assert(connection->sfd != JB_INVALID_SOCKET);

   if (mark_connection_unused(connection))
   {
      return;
   }

   privoxy_mutex_lock(&connection_reuse_mutex);

   /* Find free socket slot. */
   for (slot = 0; slot < SZ(reusable_connection); slot++)
   {
      if (reusable_connection[slot].sfd == JB_INVALID_SOCKET)
      {
         assert(reusable_connection[slot].in_use == 0);
         log_error(LOG_LEVEL_CONNECT,
            "Remembering socket %d for %s:%d in slot %d.",
            connection->sfd, connection->host, connection->port, slot);
         free_slot_found = TRUE;
         break;
      }
   }

   if (!free_slot_found)
   {
      log_error(LOG_LEVEL_CONNECT,
        "No free slots found to remember socket for %s:%d. Last slot %d.",
        connection->host, connection->port, slot);
      privoxy_mutex_unlock(&connection_reuse_mutex);
      close_socket(connection->sfd);
      return;
   }

   assert(NULL != connection->host);
   reusable_connection[slot].host = strdup_or_die(connection->host);
   reusable_connection[slot].sfd = connection->sfd;
   reusable_connection[slot].port = connection->port;
   reusable_connection[slot].in_use = 0;
   reusable_connection[slot].timestamp = connection->timestamp;
   reusable_connection[slot].request_sent = connection->request_sent;
   reusable_connection[slot].response_received = connection->response_received;
   reusable_connection[slot].keep_alive_timeout = connection->keep_alive_timeout;
   reusable_connection[slot].requests_sent_total = connection->requests_sent_total;

   assert(reusable_connection[slot].gateway_host == NULL);
   assert(reusable_connection[slot].gateway_port == 0);
   assert(reusable_connection[slot].forwarder_type == SOCKS_NONE);
   assert(reusable_connection[slot].forward_host == NULL);
   assert(reusable_connection[slot].forward_port == 0);

   reusable_connection[slot].forwarder_type = connection->forwarder_type;
   if (NULL != connection->gateway_host)
   {
      reusable_connection[slot].gateway_host = strdup_or_die(connection->gateway_host);
   }
   else
   {
      reusable_connection[slot].gateway_host = NULL;
   }
   reusable_connection[slot].gateway_port = connection->gateway_port;

   if (NULL != connection->forward_host)
   {
      reusable_connection[slot].forward_host = strdup_or_die(connection->forward_host);
   }
   else
   {
      reusable_connection[slot].forward_host = NULL;
   }
   reusable_connection[slot].forward_port = connection->forward_port;

   privoxy_mutex_unlock(&connection_reuse_mutex);
}
#endif /* def FEATURE_CONNECTION_SHARING */


/*********************************************************************
 *
 * Function    :  mark_connection_closed
 *
 * Description : Marks a reused connection closed.
 *
 * Parameters  :
 *          1  :  closed_connection = The connection to mark as closed.
 *
 * Returns     : void
 *
 *********************************************************************/
void mark_connection_closed(struct reusable_connection *closed_connection)
{
   closed_connection->in_use = FALSE;
   closed_connection->sfd = JB_INVALID_SOCKET;
   freez(closed_connection->host);
   closed_connection->port = 0;
   closed_connection->timestamp = 0;
   closed_connection->request_sent = 0;
   closed_connection->response_received = 0;
   closed_connection->keep_alive_timeout = 0;
   closed_connection->requests_sent_total = 0;
   closed_connection->forwarder_type = SOCKS_NONE;
   freez(closed_connection->gateway_host);
   closed_connection->gateway_port = 0;
   freez(closed_connection->forward_host);
   closed_connection->forward_port = 0;
}


#ifdef FEATURE_CONNECTION_SHARING
/*********************************************************************
 *
 * Function    :  forget_connection
 *
 * Description :  Removes a previously remembered connection from
 *                the list of reusable connections.
 *
 * Parameters  :
 *          1  :  sfd = The socket belonging to the connection in question.
 *
 * Returns     : void
 *
 *********************************************************************/
void forget_connection(jb_socket sfd)
{
   unsigned int slot = 0;

   assert(sfd != JB_INVALID_SOCKET);

   privoxy_mutex_lock(&connection_reuse_mutex);

   for (slot = 0; slot < SZ(reusable_connection); slot++)
   {
      if (reusable_connection[slot].sfd == sfd)
      {
         assert(reusable_connection[slot].in_use);

         log_error(LOG_LEVEL_CONNECT,
            "Forgetting socket %d for %s:%d in slot %d.",
            sfd, reusable_connection[slot].host,
            reusable_connection[slot].port, slot);
         mark_connection_closed(&reusable_connection[slot]);
         break;
      }
   }

   privoxy_mutex_unlock(&connection_reuse_mutex);

}
#endif /* def FEATURE_CONNECTION_SHARING */


#ifdef FEATURE_CONNECTION_KEEP_ALIVE
/*********************************************************************
 *
 * Function    :  connection_destination_matches
 *
 * Description :  Determines whether a remembered connection can
 *                be reused. That is, whether the destination and
 *                the forwarding settings match.
 *
 * Parameters  :
 *          1  :  connection = The connection to check.
 *          2  :  http = The destination for the connection.
 *          3  :  fwd  = The forwarder settings.
 *
 * Returns     :  TRUE for yes, FALSE otherwise.
 *
 *********************************************************************/
int connection_destination_matches(const struct reusable_connection *connection,
                                   const struct http_request *http,
                                   const struct forward_spec *fwd)
{
   if ((connection->forwarder_type != fwd->type)
    || (connection->gateway_port   != fwd->gateway_port)
    || (connection->forward_port   != fwd->forward_port)
    || (connection->port           != http->port))
   {
      return FALSE;
   }

   if ((    (NULL != connection->gateway_host)
         && (NULL != fwd->gateway_host)
         && strcmpic(connection->gateway_host, fwd->gateway_host))
       && (connection->gateway_host != fwd->gateway_host))
   {
      log_error(LOG_LEVEL_CONNECT,
         "Gateway mismatch. Previous gateway: %s. Current gateway: %s",
         connection->gateway_host, fwd->gateway_host);
      return FALSE;
   }

   if ((    (NULL != connection->forward_host)
         && (NULL != fwd->forward_host)
         && strcmpic(connection->forward_host, fwd->forward_host))
      && (connection->forward_host != fwd->forward_host))
   {
      log_error(LOG_LEVEL_CONNECT,
         "Forwarding proxy mismatch. Previous proxy: %s. Current proxy: %s",
         connection->forward_host, fwd->forward_host);
      return FALSE;
   }

   return (!strcmpic(connection->host, http->host));

}
#endif /* def FEATURE_CONNECTION_KEEP_ALIVE */


#ifdef FEATURE_CONNECTION_SHARING
/*********************************************************************
 *
 * Function    :  close_unusable_connections
 *
 * Description :  Closes remembered connections that have timed
 *                out or have been closed on the other side.
 *
 * Parameters  :  none
 *
 * Returns     :  Number of connections that are still alive.
 *
 *********************************************************************/
int close_unusable_connections(void)
{
   unsigned int slot = 0;
   int connections_alive = 0;

   privoxy_mutex_lock(&connection_reuse_mutex);

   for (slot = 0; slot < SZ(reusable_connection); slot++)
   {
      if (!reusable_connection[slot].in_use
         && (JB_INVALID_SOCKET != reusable_connection[slot].sfd))
      {
         time_t time_open = time(NULL) - reusable_connection[slot].timestamp;
         time_t latency = (reusable_connection[slot].response_received -
            reusable_connection[slot].request_sent) / 2;

         if (reusable_connection[slot].keep_alive_timeout < time_open + latency)
         {
            log_error(LOG_LEVEL_CONNECT,
               "The connection to %s:%d in slot %d timed out. "
               "Closing socket %d. Timeout is: %d. Assumed latency: %d.",
               reusable_connection[slot].host,
               reusable_connection[slot].port, slot,
               reusable_connection[slot].sfd,
               reusable_connection[slot].keep_alive_timeout,
               latency);
            close_socket(reusable_connection[slot].sfd);
            mark_connection_closed(&reusable_connection[slot]);
         }
         else if (!socket_is_still_alive(reusable_connection[slot].sfd))
         {
            log_error(LOG_LEVEL_CONNECT,
               "The connection to %s:%d in slot %d is no longer usable. "
               "Closing socket %d.", reusable_connection[slot].host,
               reusable_connection[slot].port, slot,
               reusable_connection[slot].sfd);
            close_socket(reusable_connection[slot].sfd);
            mark_connection_closed(&reusable_connection[slot]);
         }
         else
         {
            connections_alive++;
         }
      }
   }

   privoxy_mutex_unlock(&connection_reuse_mutex);

   return connections_alive;

}


/*********************************************************************
 *
 * Function    :  get_reusable_connection
 *
 * Description :  Returns an open socket to a previously remembered
 *                open connection (if there is one).
 *
 * Parameters  :
 *          1  :  http = The destination for the connection.
 *          2  :  fwd  = The forwarder settings.
 *
 * Returns     :  JB_INVALID_SOCKET => No reusable connection found,
 *                otherwise a usable socket.
 *
 *********************************************************************/
static jb_socket get_reusable_connection(const struct http_request *http,
                                         const struct forward_spec *fwd)
{
   jb_socket sfd = JB_INVALID_SOCKET;
   unsigned int slot = 0;

   close_unusable_connections();

   privoxy_mutex_lock(&connection_reuse_mutex);

   for (slot = 0; slot < SZ(reusable_connection); slot++)
   {
      if (!reusable_connection[slot].in_use
         && (JB_INVALID_SOCKET != reusable_connection[slot].sfd))
      {
         if (connection_destination_matches(&reusable_connection[slot], http, fwd))
         {
            reusable_connection[slot].in_use = TRUE;
            sfd = reusable_connection[slot].sfd;
            log_error(LOG_LEVEL_CONNECT,
               "Found reusable socket %d for %s:%d in slot %d. Timestamp made %d "
               "seconds ago. Timeout: %d. Latency: %d. Requests served: %d",
               sfd, reusable_connection[slot].host, reusable_connection[slot].port,
               slot, time(NULL) - reusable_connection[slot].timestamp,
               reusable_connection[slot].keep_alive_timeout,
               (int)(reusable_connection[slot].response_received -
               reusable_connection[slot].request_sent),
               reusable_connection[slot].requests_sent_total);
            break;
         }
      }
   }

   privoxy_mutex_unlock(&connection_reuse_mutex);

   return sfd;

}


/*********************************************************************
 *
 * Function    :  mark_connection_unused
 *
 * Description :  Gives a remembered connection free for reuse.
 *
 * Parameters  :
 *          1  :  connection = The connection in question.
 *
 * Returns     :  TRUE => Socket found and marked as unused.
 *                FALSE => Socket not found.
 *
 *********************************************************************/
static int mark_connection_unused(const struct reusable_connection *connection)
{
   unsigned int slot = 0;
   int socket_found = FALSE;

   assert(connection->sfd != JB_INVALID_SOCKET);

   privoxy_mutex_lock(&connection_reuse_mutex);

   for (slot = 0; slot < SZ(reusable_connection); slot++)
   {
      if (reusable_connection[slot].sfd == connection->sfd)
      {
         assert(reusable_connection[slot].in_use);
         socket_found = TRUE;
         log_error(LOG_LEVEL_CONNECT,
            "Marking open socket %d for %s:%d in slot %d as unused.",
            connection->sfd, reusable_connection[slot].host,
            reusable_connection[slot].port, slot);
         reusable_connection[slot].in_use = 0;
         reusable_connection[slot].timestamp = connection->timestamp;
         break;
      }
   }

   privoxy_mutex_unlock(&connection_reuse_mutex);

   return socket_found;

}


/*********************************************************************
 *
 * Function    :  set_keep_alive_timeout
 *
 * Description :  Sets the timeout after which open
 *                connections will no longer be reused.
 *
 * Parameters  :
 *          1  :  timeout = The timeout in seconds.
 *
 * Returns     :  void
 *
 *********************************************************************/
void set_keep_alive_timeout(unsigned int timeout)
{
   keep_alive_timeout = timeout;
}
#endif /* def FEATURE_CONNECTION_SHARING */


/*********************************************************************
 *
 * Function    :  forwarded_connect
 *
 * Description :  Connect to a specified web server, possibly via
 *                a HTTP proxy and/or a SOCKS proxy.
 *
 * Parameters  :
 *          1  :  fwd = the proxies to use when connecting.
 *          2  :  http = the http request and apropos headers
 *          3  :  csp = Current client state (buffers, headers, etc...)
 *
 * Returns     :  JB_INVALID_SOCKET => failure, else it is the socket file descriptor.
 *
 *********************************************************************/
jb_socket forwarded_connect(const struct forward_spec * fwd,
                            struct http_request *http,
                            struct client_state *csp)
{
   const char * dest_host;
   int dest_port;
   jb_socket sfd = JB_INVALID_SOCKET;

#ifdef FEATURE_CONNECTION_SHARING
   if ((csp->config->feature_flags & RUNTIME_FEATURE_CONNECTION_SHARING)
      && !(csp->flags & CSP_FLAG_SERVER_SOCKET_TAINTED))
   {
      sfd = get_reusable_connection(http, fwd);
      if (JB_INVALID_SOCKET != sfd)
      {
         return sfd;
      }
   }
#endif /* def FEATURE_CONNECTION_SHARING */

   /* Figure out if we need to connect to the web server or a HTTP proxy. */
    sfd = connect_to_forward(csp, fwd, 0);

    if (JB_INVALID_SOCKET != sfd)
    {
        log_error(LOG_LEVEL_CONNECT,
         "Created new connection to %s:%d on socket %d.",
         http->host, http->port, sfd);
    }

    return sfd;

}


/*********************************************************************
 *
 * Function    :  socks4_connect
 *
 * Description :  Connect to the SOCKS server, and connect through
 *                it to the specified server.   This handles
 *                all the SOCKS negotiation, and returns a file
 *                descriptor for a socket which can be treated as a
 *                normal (non-SOCKS) socket.
 *
 *                Logged error messages are saved to csp->error_message
 *                and later reused by error_response() for the CGI
 *                message. strdup allocation failures are handled there.
 *
 * Parameters  :
 *          1  :  fwd = Specifies the SOCKS proxy to use.
 *          2  :  target_host = The final server to connect to.
 *          3  :  target_port = The final port to connect to.
 *          4  :  csp = Current client state (buffers, headers, etc...)
 *
 * Returns     :  JB_INVALID_SOCKET => failure, else a socket file descriptor.
 *
 *********************************************************************/
jb_socket socks4_connect(char *gateway_host,
                         int gateway_port,
                         enum forwarder_type type,
                                const char * target_host,
                                int target_port,
                                struct client_state *csp)
{
   unsigned long web_server_addr;
   char buf[BUFFER_SIZE];
   struct socks_op    *c = (struct socks_op    *)buf;
   struct socks_reply *s = (struct socks_reply *)buf;
   size_t n;
   size_t csiz;
   jb_socket sfd;
   int err = 0;
   char *errstr = NULL;

   if ((gateway_host == NULL) || (*gateway_host == '\0'))
   {
      /* XXX: Shouldn't the config file parser prevent this? */
      errstr = "NULL gateway host specified.";
      err = 1;
   }

   if (gateway_port <= 0)
   {
      errstr = "invalid gateway port specified.";
      err = 1;
   }

   if (err)
   {
      log_error(LOG_LEVEL_CONNECT, "socks4_connect: %s", errstr);
      csp->error_message = strdup(errstr);
      errno = EINVAL;
      return(JB_INVALID_SOCKET);
   }

   /* build a socks request for connection to the web server */

   strlcpy(&(c->userid), socks_userid, sizeof(buf) - sizeof(struct socks_op));

   csiz = sizeof(*c) + sizeof(socks_userid) - sizeof(c->userid) - sizeof(c->padding);

   switch (type)
   {
      case SOCKS_4:
         web_server_addr = resolve_hostname_to_ip(target_host);
         if (web_server_addr == INADDR_NONE)
         {
            errstr = "could not resolve target host";
            log_error(LOG_LEVEL_CONNECT, "socks4_connect: %s %s", errstr, target_host);
            err = 1;
         }
         else
         {
            web_server_addr = htonl(web_server_addr);
         }
         break;
      case SOCKS_4A:
         web_server_addr = 0x00000001;
         n = csiz + strlen(target_host) + 1;
         if (n > sizeof(buf))
         {
            errno = EINVAL;
            errstr = "buffer cbuf too small.";
            log_error(LOG_LEVEL_CONNECT, "socks4_connect: %s", errstr);
            err = 1;
         }
         else
         {
            strlcpy(buf + csiz, target_host, sizeof(buf) - sizeof(struct socks_op) - csiz);
            /*
             * What we forward to the socks4a server should have the
             * size of socks_op, plus the length of the userid plus
             * its \0 byte (which we don't have to add because the
             * first byte of the userid is counted twice as it's also
             * part of sock_op) minus the padding bytes (which are part
             * of the userid as well), plus the length of the target_host
             * (which is stored csiz bytes after the beginning of the buffer),
             * plus another \0 byte.
             */
            assert(n == sizeof(struct socks_op) + strlen(&(c->userid)) - sizeof(c->padding) + strlen(buf + csiz) + 1);
            csiz = n;
         }
         break;
      default:
         /* Should never get here */
         log_error(LOG_LEVEL_FATAL,
            "socks4_connect: SOCKS4 impossible internal error - bad SOCKS type.");
         /* Not reached */
         return(JB_INVALID_SOCKET);
   }

   if (err)
   {
      csp->error_message = strdup(errstr);
      return(JB_INVALID_SOCKET);
   }

   c->vn          = 4;
   c->cd          = 1;
   c->dstport[0]  = (unsigned char)((target_port       >> 8 ) & 0xff);
   c->dstport[1]  = (unsigned char)((target_port            ) & 0xff);
   c->dstip[0]    = (unsigned char)((web_server_addr   >> 24) & 0xff);
   c->dstip[1]    = (unsigned char)((web_server_addr   >> 16) & 0xff);
   c->dstip[2]    = (unsigned char)((web_server_addr   >>  8) & 0xff);
   c->dstip[3]    = (unsigned char)((web_server_addr        ) & 0xff);

   /* pass the request to the socks server */
   sfd = connect_to(gateway_host, gateway_port, csp, 1);

   if (sfd == JB_INVALID_SOCKET)
   {
      /* The error an its reason have already been logged by connect_to()  */
      return(JB_INVALID_SOCKET);
   }
   else if (write_socket(sfd, (char *)c, csiz))
   {
      errstr = "SOCKS4 negotiation write failed.";
      log_error(LOG_LEVEL_CONNECT, "socks4_connect: %s", errstr);
      err = 1;
      close_socket(sfd);
   }
   else if (!data_is_available(sfd, csp->config->socket_timeout))
   {
      if (socket_is_still_alive(sfd))
      {
         errstr = "SOCKS4 negotiation timed out";
      }
      else
      {
         errstr = "SOCKS4 negotiation got aborted by the server";
      }
      log_error(LOG_LEVEL_CONNECT, "socks4_connect: %s", errstr);
      err = 1;
      close_socket(sfd);
   }
   else if (read_socket(sfd, buf, sizeof(buf)) != sizeof(*s))
   {
      errstr = "SOCKS4 negotiation read failed.";
      log_error(LOG_LEVEL_CONNECT, "socks4_connect: %s", errstr);
      err = 1;
      close_socket(sfd);
   }

   if (err)
   {
      csp->error_message = strdup(errstr);
      return(JB_INVALID_SOCKET);
   }

   switch (s->cd)
   {
      case SOCKS4_REQUEST_GRANTED:
         return(sfd);
      case SOCKS4_REQUEST_REJECT:
         errstr = "SOCKS request rejected or failed.";
         errno = EINVAL;
         break;
      case SOCKS4_REQUEST_IDENT_FAILED:
         errstr = "SOCKS request rejected because "
            "SOCKS server cannot connect to identd on the client.";
         errno = EACCES;
         break;
      case SOCKS4_REQUEST_IDENT_CONFLICT:
         errstr = "SOCKS request rejected because "
            "the client program and identd report "
            "different user-ids.";
         errno = EACCES;
         break;
      default:
         errno = ENOENT;
         snprintf(buf, sizeof(buf),
            "SOCKS request rejected for reason code %d.", s->cd);
         errstr = buf;
   }

   log_error(LOG_LEVEL_CONNECT, "socks4_connect: %s", errstr);
   csp->error_message = strdup(errstr);
   close_socket(sfd);

   return(JB_INVALID_SOCKET);

}

/*********************************************************************
 *
 * Function    :  translate_socks5_error
 *
 * Description :  Translates a SOCKS errors to a string.
 *
 * Parameters  :
 *          1  :  socks_error = The error code to translate.
 *
 * Returns     :  The string translation.
 *
 *********************************************************************/
static const char *translate_socks5_error(int socks_error)
{
   switch (socks_error)
   {
      /* XXX: these should be more descriptive */
      case SOCKS5_REQUEST_FAILED:
         return "SOCKS5 request failed";
      case SOCKS5_REQUEST_DENIED:
         return "SOCKS5 request denied";
      case SOCKS5_REQUEST_NETWORK_UNREACHABLE:
         return "SOCKS5 network unreachable";
      case SOCKS5_REQUEST_HOST_UNREACHABLE:
         return "SOCKS5 destination host unreachable";
      case SOCKS5_REQUEST_CONNECTION_REFUSED:
         return "SOCKS5 connection refused";
      case SOCKS5_REQUEST_TTL_EXPIRED:
         return "SOCKS5 TTL expired";
      case SOCKS5_REQUEST_PROTOCOL_ERROR:
         return "SOCKS5 client protocol error";
      case SOCKS5_REQUEST_BAD_ADDRESS_TYPE:
         return "SOCKS5 domain names unsupported";
      case SOCKS5_REQUEST_GRANTED:
         return "everything's peachy";
      default:
         return "SOCKS5 negotiation protocol error";
   }
}

/*********************************************************************
 *
 * Function    :  socks5_connect
 *
 * Description :  Connect to the SOCKS server, and connect through
 *                it to the specified server.   This handles
 *                all the SOCKS negotiation, and returns a file
 *                descriptor for a socket which can be treated as a
 *                normal (non-SOCKS) socket.
 *
 * Parameters  :
 *          1  :  fwd = Specifies the SOCKS proxy to use.
 *          2  :  target_host = The final server to connect to.
 *          3  :  target_port = The final port to connect to.
 *          4  :  csp = Current client state (buffers, headers, etc...)
 *
 * Returns     :  JB_INVALID_SOCKET => failure, else a socket file descriptor.
 *
 *********************************************************************/
jb_socket socks5_connect(char *gateway_host,
                        int gateway_port,
                         enum forwarder_type type,
                                const char *target_host,
                                int target_port,
                                struct client_state *csp)
{
   int err = 0;
   char cbuf[300];
   char sbuf[10];
   size_t client_pos = 0;
   int server_size = 0;
   size_t hostlen = 0;
   jb_socket sfd;
   const char *errstr = NULL;

   assert(gateway_host);
   if ((gateway_host == NULL) || (*gateway_host == '\0'))
   {
      errstr = "NULL gateway host specified";
      err = 1;
   }

   if (gateway_port <= 0)
   {
      /*
       * XXX: currently this can't happen because in
       * case of invalid gateway ports we use the defaults.
       * Of course we really shouldn't do that.
       */
      errstr = "invalid gateway port specified";
      err = 1;
   }

   hostlen = strlen(target_host);
   if (hostlen > (size_t)255)
   {
      errstr = "target host name is longer than 255 characters";
      err = 1;
   }

   if ((type != SOCKS_5) && (type != SOCKS_5T))
   {
      /* Should never get here */
      log_error(LOG_LEVEL_FATAL,
         "SOCKS5 impossible internal error - bad SOCKS type");
      err = 1;
   }

   if (err)
   {
      errno = EINVAL;
      assert(errstr != NULL);
      log_error(LOG_LEVEL_CONNECT, "socks5_connect: %s", errstr);
      csp->error_message = strdup(errstr);
      return(JB_INVALID_SOCKET);
   }

   /* pass the request to the socks server */
   sfd = connect_to(gateway_host, gateway_port, csp, 1);

   if (sfd == JB_INVALID_SOCKET)
   {
      errstr = "socks5 server unreachable";
      log_error(LOG_LEVEL_CONNECT, "socks5_connect: %s", errstr);
      /* Free the generic error message provided by connect_to() */
      freez(csp->error_message);
      csp->error_message = strdup(errstr);
      return(JB_INVALID_SOCKET);
   }

   client_pos = 0;
   cbuf[client_pos++] = '\x05'; /* Version */
   cbuf[client_pos++] = '\x01'; /* One authentication method supported */
   cbuf[client_pos++] = '\x00'; /* The no authentication authentication method */

   if (write_socket(sfd, cbuf, client_pos))
   {
      errstr = "SOCKS5 negotiation write failed";
      csp->error_message = strdup(errstr);
      log_error(LOG_LEVEL_CONNECT, "%s", errstr);
      close_socket(sfd);
      return(JB_INVALID_SOCKET);
   }

   if (!data_is_available(sfd, csp->config->socket_timeout))
   {
      if (socket_is_still_alive(sfd))
      {
         errstr = "SOCKS5 negotiation timed out";
      }
      else
      {
         errstr = "SOCKS5 negotiation got aborted by the server";
      }
      err = 1;
   }

   if (!err && read_socket(sfd, sbuf, sizeof(sbuf)) != 2)
   {
      errstr = "SOCKS5 negotiation read failed";
      err = 1;
   }

   if (!err && (sbuf[0] != '\x05'))
   {
      errstr = "SOCKS5 negotiation protocol version error";
      err = 1;
   }

   if (!err && (sbuf[1] == '\xff'))
   {
      errstr = "SOCKS5 authentication required";
      err = 1;
   }

   if (!err && (sbuf[1] != '\x00'))
   {
      errstr = "SOCKS5 negotiation protocol error";
      err = 1;
   }

   if (err)
   {
      assert(errstr != NULL);
      log_error(LOG_LEVEL_CONNECT, "socks5_connect: %s", errstr);
      csp->error_message = strdup(errstr);
      close_socket(sfd);
      errno = EINVAL;
      return(JB_INVALID_SOCKET);
   }

   client_pos = 0;
   cbuf[client_pos++] = '\x05'; /* Version */
   cbuf[client_pos++] = '\x01'; /* TCP connect */
   cbuf[client_pos++] = '\x00'; /* Reserved, must be 0x00 */
   cbuf[client_pos++] = '\x03'; /* Address is domain name */
   cbuf[client_pos++] = (char)(hostlen & 0xffu);
   assert(sizeof(cbuf) - client_pos > (size_t)255);
   /* Using strncpy because we really want the nul byte padding. */
   strncpy(cbuf + client_pos, target_host, sizeof(cbuf) - client_pos);
   client_pos += (hostlen & 0xffu);
   cbuf[client_pos++] = (char)((target_port >> 8) & 0xff);
   cbuf[client_pos++] = (char)((target_port     ) & 0xff);

   if (write_socket(sfd, cbuf, client_pos))
   {
      errstr = "SOCKS5 negotiation write failed";
      csp->error_message = strdup(errstr);
      log_error(LOG_LEVEL_CONNECT, "%s", errstr);
      close_socket(sfd);
      errno = EINVAL;
      return(JB_INVALID_SOCKET);
   }

   /*
    * Optimistically send the HTTP request with the initial
    * SOCKS request if the user enabled the use of Tor extensions,
    * the CONNECT method isn't being used (in which case the client
    * doesn't send data until it gets our 200 response) and the
    * client request has actually been completely read already.
    */
   if ((type == SOCKS_5T) && (csp->http->ssl == 0)
      && (csp->flags & CSP_FLAG_CLIENT_REQUEST_COMPLETELY_READ))
   {
      char *client_headers = list_to_text(csp->headers);
      size_t header_length;

      if (client_headers == NULL)
      {
         log_error(LOG_LEVEL_FATAL, "Out of memory rebuilding client headers");
      }
      list_remove_all(csp->headers);
      header_length= strlen(client_headers);

      log_error(LOG_LEVEL_CONNECT,
         "Optimistically sending %d bytes of client headers intended for %s",
         header_length, csp->http->hostport);

      if (write_socket(sfd, client_headers, header_length))
      {
         log_error(LOG_LEVEL_CONNECT,
            "optimistically writing header to: %s failed: %E", csp->http->hostport);
         freez(client_headers);
         return(JB_INVALID_SOCKET);
      }
      freez(client_headers);
      if (csp->expected_client_content_length != 0)
      {
         unsigned long long buffered_request_bytes =
            (unsigned long long)(csp->client_iob->eod - csp->client_iob->cur);
         log_error(LOG_LEVEL_CONNECT,
            "Optimistically sending %d bytes of client body. Expected %d",
            csp->expected_client_content_length, buffered_request_bytes);
         assert(csp->expected_client_content_length == buffered_request_bytes);
         if (write_socket(sfd, csp->client_iob->cur, buffered_request_bytes))
         {
            log_error(LOG_LEVEL_CONNECT,
               "optimistically writing %d bytes of client body to: %s failed: %E",
               buffered_request_bytes, csp->http->hostport);
            return(JB_INVALID_SOCKET);
         }
         clear_iob(csp->client_iob);
      }
   }

   server_size = read_socket(sfd, sbuf, sizeof(sbuf));
   if (server_size != sizeof(sbuf))
   {
      errstr = "SOCKS5 negotiation read failed";
   }
   else
   {
      if (sbuf[0] != '\x05')
      {
         errstr = "SOCKS5 negotiation protocol version error";
      }
      else if (sbuf[2] != '\x00')
      {
         errstr = "SOCKS5 negotiation protocol error";
      }
      else if (sbuf[1] != SOCKS5_REQUEST_GRANTED)
      {
         errstr = translate_socks5_error(sbuf[1]);
      }
      else
      {
         return(sfd);
      }
   }

   assert(errstr != NULL);
   csp->error_message = strdup(errstr);
   log_error(LOG_LEVEL_CONNECT, "socks5_connect: %s", errstr);
   close_socket(sfd);
   errno = EINVAL;

   return(JB_INVALID_SOCKET);

}

/*
  Local Variables:
  tab-width: 3
  end:
*/
