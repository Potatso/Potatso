#ifndef PROJECT_H_INCLUDED
#define PROJECT_H_INCLUDED
/** Version string. */
#define PROJECT_H_VERSION "$Id: project.h,v 1.212 2016/01/16 12:30:43 fabiankeil Exp $"
/*********************************************************************
 *
 * File        :  $Source: /cvsroot/ijbswa/current/project.h,v $
 *
 * Purpose     :  Defines data structures which are widely used in the
 *                project.  Does not define any variables or functions
 *                (though it does declare some macros).
 *
 * Copyright   :  Written by and Copyright (C) 2001-2014 the
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


/* Declare struct FILE for vars and funcs. */
#include <stdio.h>

/* Need time_t for file_list */
#include <time.h>
/* Needed for pcre choice */
#include "sp_config.h"

/* Need for struct sockaddr_storage */
#ifdef HAVE_RFC2553
#  ifndef _WIN32
#    include <netdb.h>
#    include <sys/socket.h>
#  else
#    include <stdint.h>
#    include <winsock2.h>
#    include <ws2tcpip.h>
     typedef unsigned short in_port_t;
#  endif
#endif


/*
 * Include appropriate regular expression libraries.
 * Note that pcrs and pcre (native) are needed for cgi
 * and are included anyway.
 */

#ifdef STATIC_PCRE
#  include "pcre.h"
#else
#  ifdef PCRE_H_IN_SUBDIR
#    include <pcre/pcre.h>
#  else
#    include "pcre.h"
#  endif
#endif

#ifdef STATIC_PCRS
#  include "pcrs.h"
#else
#  include <pcrs.h>
#endif

#ifdef STATIC_PCRE
#  include "pcreposix.h"
#else
#  ifdef PCRE_H_IN_SUBDIR
#    include <pcre/pcreposix.h>
#  else
#    include "pcreposix.h"
#  endif
#endif

//#include <regex.h>

#ifdef _WIN32
/*
 * I don't want to have to #include all this just for the declaration
 * of SOCKET.  However, it looks like we have to...
 */
#ifndef STRICT
#define STRICT
#endif
#include <windows.h>
#endif


#ifdef _WIN32

typedef SOCKET jb_socket;

#define JB_INVALID_SOCKET INVALID_SOCKET

#else /* ndef _WIN32 */

/**
 * The type used by sockets.  On UNIX it's an int.  Microsoft decided to
 * make it an unsigned.
 */
typedef int jb_socket;

/**
 * The error value used for variables of type jb_socket.  On UNIX this
 * is -1, however Microsoft decided to make socket handles unsigned, so
 * they use a different value.
 */

#define JB_INVALID_SOCKET (-1)

#endif /* ndef _WIN32 */


#include "radix.h"
#include "maxminddb.h"

extern MMDB_s mmdb;

/**
 * A standard error code.  This should be JB_ERR_OK or one of the JB_ERR_xxx
 * series of errors.
 */
enum privoxy_err
{
   JB_ERR_OK         = 0, /**< Success, no error                        */
   JB_ERR_MEMORY     = 1, /**< Out of memory                            */
   JB_ERR_CGI_PARAMS = 2, /**< Missing or corrupt CGI parameters        */
   JB_ERR_FILE       = 3, /**< Error opening, reading or writing a file */
   JB_ERR_PARSE      = 4, /**< Error parsing file                       */
   JB_ERR_MODIFIED   = 5, /**< File has been modified outside of the
                               CGI actions editor.                      */
   JB_ERR_COMPRESS   = 6  /**< Error on decompression                   */
};

typedef enum privoxy_err jb_err;

/**
 * This macro is used to free a pointer that may be NULL.
 * It also sets the variable to NULL after it's been freed.
 * The paramater should be a simple variable without side effects.
 */
#define freez(X)  { if(X) { free((void*)X); X = NULL ; } }


/**
 * Macro definitions for platforms where isspace() and friends
 * are macros that use their argument directly as an array index
 * and thus better be positive. Supposedly that's the case on
 * some unspecified Solaris versions.
 * Note: Remember to #include <ctype.h> if you use these macros.
 */
#define privoxy_isdigit(__X) isdigit((int)(unsigned char)(__X))
#define privoxy_isupper(__X) isupper((int)(unsigned char)(__X))
#define privoxy_toupper(__X) toupper((int)(unsigned char)(__X))
#define privoxy_tolower(__X) tolower((int)(unsigned char)(__X))
#define privoxy_isspace(__X) isspace((int)(unsigned char)(__X))

/**
 * Use for statically allocated buffers if you have no other choice.
 * Remember to check the length of what you write into the buffer
 * - we don't want any buffer overflows!
 */
#define BUFFER_SIZE 5000

/**
 * Max length of CGI parameters (arbitrary limit).
 */
#define CGI_PARAM_LEN_MAX 500U

/**
 * Buffer size for capturing struct hostent data in the
 * gethostby(name|addr)_r library calls. Since we don't
 * loop over gethostbyname_r, the buffer must be sufficient
 * to accommodate multiple IN A RRs, as used in DNS round robin
 * load balancing. W3C's wwwlib uses 1K, so that should be
 * good enough for us, too.
 */
/**
 * XXX: Temporary doubled, for some configurations
 * 1K is still too small and we didn't get the
 * real fix ready for inclusion.
 */
#define HOSTENT_BUFFER_SIZE 2048

/**
 * Default TCP/IP address to listen on, as a string.
 * Set to "127.0.0.1:8118".
 */
#define HADDR_DEFAULT   "127.0.0.1:8118"


/* Forward def for struct client_state */
struct configuration_spec;


/**
 * Entry in a linked list of strings.
 */
struct list_entry
{
   /**
    * The string pointer. It must point to a dynamically malloc()ed
    * string or be NULL for the list functions to work. In the latter
    * case, just be careful next time you iterate through the list in
    * your own code.
    */
   char *str;

   /** Next entry in the linked list, or NULL if no more. */
   struct list_entry *next;
};

/**
 * A header for a linked list of strings.
 */
struct list
{
   /** First entry in the list, or NULL if the list is empty. */
   struct list_entry *first;

   /** Last entry in the list, or NULL if the list is empty. */
   struct list_entry *last;
};


/**
 * An entry in a map.  This is a name=value pair.
 */
struct map_entry
{
   /** The key for the map. */
   const char *name;
   /** The value associated with that key. */
   const char *value;
   /** The next map entry, or NULL if none. */
   struct map_entry *next;
};

/**
 * A map from a string to another string.
 * This is used for the paramaters passed in a HTTP GET request, and
 * to store the exports when the CGI interface is filling in a template.
 */
struct map
{
   /** The first map entry, or NULL if the map is empty. */
   struct map_entry *first;
   /** The last map entry, or NULL if the map is empty. */
   struct map_entry *last;
};


/**
 * A HTTP request.  This includes the method (GET, POST) and
 * the parsed URL.
 *
 * This is also used whenever we want to match a URL against a
 * URL pattern.  This always contains the URL to match, and never
 * a URL pattern.  (See struct url_spec).
 */
struct http_request
{
   char *cmd;      /**< Whole command line: method, URL, Version */
   char *ocmd;     /**< Backup of original cmd for CLF logging */
   char *gpc;      /**< HTTP method: GET, POST, ... */
   char *url;      /**< The URL */
   char *ver;      /**< Protocol version */
   int status;     /**< HTTP Status */

   char *host;     /**< Host part of URL */
   int   port;     /**< Port of URL or 80 (default) */
   char *path;     /**< Path of URL */
   char *hostport; /**< host[:port] */
   int   ssl;      /**< Flag if protocol is https */

   char *remote_host_ip_addr_str; /**< String with dotted decimal representation
                             of remote host's IP. NULL before connect_to() */

   char *host_ip_addr_str; /**< String with dotted decimal representation
                                of host's IP. NULL before connect_to() */

#ifndef FEATURE_EXTENDED_HOST_PATTERNS
   char  *dbuffer; /**< Buffer with '\0'-delimited domain name.           */
   char **dvec;    /**< List of pointers to the strings in dbuffer.       */
   int    dcount;  /**< How many parts to this domain? (length of dvec)   */
#endif /* ndef FEATURE_EXTENDED_HOST_PATTERNS */
};

/**
 * Reasons for generating a http_response instead of delivering
 * the requested resource. Mostly ordered the way they are checked
 * for in chat().
 */
enum crunch_reason
{
   UNSUPPORTED,
   BLOCKED,
   UNTRUSTED,
   REDIRECTED,
   CGI_CALL,
   NO_SUCH_DOMAIN,
   FORWARDING_FAILED,
   CONNECT_FAILED,
   OUT_OF_MEMORY,
   INTERNAL_ERROR,
   CONNECTION_TIMEOUT,
   NO_SERVER_DATA
};

/**
 * Response generated by CGI, blocker, or error handler
 */
struct http_response
{
  char  *status;                    /**< HTTP status (string). */
  struct list headers[1];           /**< List of header lines. */
  char  *head;                      /**< Formatted http response head. */
  size_t head_length;               /**< Length of http response head. */
  char  *body;                      /**< HTTP document body. */
  size_t content_length;            /**< Length of body, REQUIRED if binary body. */
  int    is_static;                 /**< Nonzero if the content will never change and
                                         should be cached by the browser (e.g. images). */
  enum crunch_reason crunch_reason; /**< Why the response was generated in the first place. */
};

struct url_spec
{
#ifdef FEATURE_EXTENDED_HOST_PATTERNS
   regex_t *host_regex;/**< Regex for host matching                          */
#else
   char  *dbuffer;     /**< Buffer with '\0'-delimited domain name, or NULL to match all hosts. */
   char **dvec;        /**< List of pointers to the strings in dbuffer.       */
   int    dcount;      /**< How many parts to this domain? (length of dvec)   */
   int    unanchored;  /**< Bitmap - flags are ANCHOR_LEFT and ANCHOR_RIGHT.  */
#endif /* defined FEATURE_EXTENDED_HOST_PATTERNS */

   char  *port_list;   /**< List of acceptable ports, or NULL to match all ports */

   regex_t *preg;      /**< Regex for matching path part                      */
};

/**
 * A URL or a tag pattern.
 */
struct pattern_spec
{
   /** The string which was parsed to produce this pattern_spec.
       Used for debugging or display only.  */
   char  *spec;

   union
   {
      struct url_spec url_spec;
      regex_t *tag_regex;
   } pattern;

   unsigned int flags; /**< Bitmap with various pattern properties. */
};

/**
 * Constant for host part matching in URLs.  If set, indicates that the start of
 * the pattern must match the start of the URL.  E.g. this is not set for the
 * pattern ".example.com", so that it will match both "example.com" and
 * "www.example.com".  It is set for the pattern "example.com", which makes it
 * match "example.com" only, not "www.example.com".
 */
#define ANCHOR_LEFT  1

/**
 * Constant for host part matching in URLs.  If set, indicates that the end of
 * the pattern must match the end of the URL.  E.g. this is not set for the
 * pattern "ad.", so that it will match any host called "ad", irrespective
 * of how many subdomains are in the fully-qualified domain name.
 */
#define ANCHOR_RIGHT 2

/** Pattern spec bitmap: It's an URL pattern. */
#define PATTERN_SPEC_URL_PATTERN          0x00000001UL

/** Pattern spec bitmap: It's a TAG pattern. */
#define PATTERN_SPEC_TAG_PATTERN          0x00000002UL

/** Pattern spec bitmap: It's a NO-REQUEST-TAG pattern. */
#define PATTERN_SPEC_NO_REQUEST_TAG_PATTERN 0x00000004UL

/** Pattern spec bitmap: It's a NO-RESPONSE-TAG pattern. */
#define PATTERN_SPEC_NO_RESPONSE_TAG_PATTERN 0x00000008UL

/**
 * An I/O buffer.  Holds a string which can be appended to, and can have data
 * removed from the beginning.
 */
struct iob
{
   char *buf;    /**< Start of buffer        */
   char *cur;    /**< Start of relevant data */
   char *eod;    /**< End of relevant data   */
   size_t size;  /**< Size as malloc()ed     */
};


/**
 * Return the number of bytes in the I/O buffer associated with the passed
 * I/O buffer. May be zero.
 */
#define IOB_PEEK(IOB) ((IOB->cur > IOB->eod) ? (IOB->eod - IOB->cur) : 0)


/* Bits for csp->content_type bitmask: */
#define CT_TEXT    0x0001U /**< Suitable for pcrs filtering. */
#define CT_GIF     0x0002U /**< Suitable for GIF filtering.  */
#define CT_TABOO   0x0004U /**< DO NOT filter, irrespective of other flags. */

/* Although these are not, strictly speaking, content types
 * (they are content encodings), it is simple to handle them
 * as such.
 */
#define CT_GZIP    0x0010U /**< gzip-compressed data. */
#define CT_DEFLATE 0x0020U /**< zlib-compressed data. */

/**
 * Flag to signal that the server declared the content type,
 * so we can differentiate between unknown and undeclared
 * content types.
 */
#define CT_DECLARED 0x0040U

/**
 * The mask which includes all actions.
 */
#define ACTION_MASK_ALL        (~0UL)

/**
 * The most compatible set of actions - i.e. none.
 */
#define ACTION_MOST_COMPATIBLE                       0x00000000UL

/** Action bitmap: Block the request. */
#define ACTION_BLOCK                                 0x00000001UL
/** Action bitmap: Deanimate if it's a GIF. */
#define ACTION_DEANIMATE                             0x00000002UL
/** Action bitmap: Downgrade HTTP/1.1 to 1.0. */
#define ACTION_DOWNGRADE                             0x00000004UL
/** Action bitmap: Fast redirects. */
#define ACTION_FAST_REDIRECTS                        0x00000008UL
/** Action bitmap: Remove or add "X-Forwarded-For" header. */
#define ACTION_CHANGE_X_FORWARDED_FOR                0x00000010UL
/** Action bitmap: Hide "From" header. */
#define ACTION_HIDE_FROM                             0x00000020UL
/** Action bitmap: Hide "Referer" header.  (sic - follow HTTP, not English). */
#define ACTION_HIDE_REFERER                          0x00000040UL
/** Action bitmap: Hide "User-Agent" and similar headers. */
#define ACTION_HIDE_USER_AGENT                       0x00000080UL
/** Action bitmap: This is an image. */
#define ACTION_IMAGE                                 0x00000100UL
/** Action bitmap: Sets the image blocker. */
#define ACTION_IMAGE_BLOCKER                         0x00000200UL
/** Action bitmap: Prevent compression. */
#define ACTION_NO_COMPRESSION                        0x00000400UL
/** Action bitmap: Change cookies to session only cookies. */
#define ACTION_SESSION_COOKIES_ONLY                  0x00000800UL
/** Action bitmap: Block cookies coming from the client. */
#define ACTION_CRUNCH_OUTGOING_COOKIES               0x00001000UL
/** Action bitmap: Block cookies coming from the server. */
#define ACTION_CRUNCH_INCOMING_COOKIES               0x00002000UL
/** Action bitmap: Override the forward settings in the config file */
#define ACTION_FORWARD_OVERRIDE                      0x00004000UL
/** Action bitmap: Block as empty document */
#define  ACTION_HANDLE_AS_EMPTY_DOCUMENT             0x00008000UL
/** Action bitmap: Limit CONNECT requests to safe ports. */
#define ACTION_LIMIT_CONNECT                         0x00010000UL
/** Action bitmap: Redirect request. */
#define  ACTION_REDIRECT                             0x00020000UL
/** Action bitmap: Crunch or modify "if-modified-since" header. */
#define ACTION_HIDE_IF_MODIFIED_SINCE                0x00040000UL
/** Action bitmap: Overwrite Content-Type header. */
#define ACTION_CONTENT_TYPE_OVERWRITE                0x00080000UL
/** Action bitmap: Crunch specified server header. */
#define ACTION_CRUNCH_SERVER_HEADER                  0x00100000UL
/** Action bitmap: Crunch specified client header */
#define ACTION_CRUNCH_CLIENT_HEADER                  0x00200000UL
/** Action bitmap: Enable text mode by force */
#define ACTION_FORCE_TEXT_MODE                       0x00400000UL
/** Action bitmap: Enable text mode by force */
#define ACTION_CRUNCH_IF_NONE_MATCH                  0x00800000UL
/** Action bitmap: Enable content-disposition crunching */
#define ACTION_HIDE_CONTENT_DISPOSITION              0x01000000UL
/** Action bitmap: Replace or block Last-Modified header */
#define ACTION_OVERWRITE_LAST_MODIFIED               0x02000000UL
/** Action bitmap: Replace or block Accept-Language header */
#define ACTION_HIDE_ACCEPT_LANGUAGE                  0x04000000UL
/** Action bitmap: Limit the cookie lifetime */
#define ACTION_LIMIT_COOKIE_LIFETIME                 0x08000000UL

#define ACTION_FORWARD_RESOLVED_IP                   0x10000000UL

#define ACTION_FORWARD_RULE                          0x20000000UL


/** Action string index: How to deanimate GIFs */
#define ACTION_STRING_DEANIMATE             0
/** Action string index: Replacement for "From:" header */
#define ACTION_STRING_FROM                  1
/** Action string index: How to block images */
#define ACTION_STRING_IMAGE_BLOCKER         2
/** Action string index: Replacement for "Referer:" header */
#define ACTION_STRING_REFERER               3
/** Action string index: Replacement for "User-Agent:" header */
#define ACTION_STRING_USER_AGENT            4
/** Action string index: Legal CONNECT ports. */
#define ACTION_STRING_LIMIT_CONNECT         5
/** Action string index: Server headers containing this pattern are crunched*/
#define ACTION_STRING_SERVER_HEADER         6
/** Action string index: Client headers containing this pattern are crunched*/
#define ACTION_STRING_CLIENT_HEADER         7
/** Action string index: Replacement for the "Accept-Language:" header*/
#define ACTION_STRING_LANGUAGE              8
/** Action string index: Replacement for the "Content-Type:" header*/
#define ACTION_STRING_CONTENT_TYPE          9
/** Action string index: Replacement for the "content-disposition:" header*/
#define ACTION_STRING_CONTENT_DISPOSITION  10
/** Action string index: Replacement for the "If-Modified-Since:" header*/
#define ACTION_STRING_IF_MODIFIED_SINCE    11
/** Action string index: Replacement for the "Last-Modified:" header. */
#define ACTION_STRING_LAST_MODIFIED        12
/** Action string index: Redirect URL */
#define ACTION_STRING_REDIRECT             13
/** Action string index: Decode before redirect? */
#define ACTION_STRING_FAST_REDIRECTS       14
/** Action string index: Overriding forward rule. */
#define ACTION_STRING_FORWARD_OVERRIDE     15
/** Action string index: Reason for the block. */
#define ACTION_STRING_BLOCK                16
/** Action string index: what to do with the "X-Forwarded-For" header. */
#define ACTION_STRING_CHANGE_X_FORWARDED_FOR 17
/** Action string index: how many minutes cookies should be valid. */
#define ACTION_STRING_LIMIT_COOKIE_LIFETIME 18
/** Action string index: forward resolved ip. */
#define ACTION_STRING_FORWARD_RESOLVED_IP    19
/** Action string index: forward rule. */
#define ACTION_STRING_FORWARD_RULE          20
/** Number of string actions. */
#define ACTION_STRING_COUNT                21



/* To make the ugly hack in sed easier to understand */
#define CHECK_EVERY_HEADER_REMAINING 0


/** Index into current_action_spec::multi[] for headers to add. */
#define ACTION_MULTI_ADD_HEADER              0
/** Index into current_action_spec::multi[] for content filters to apply. */
#define ACTION_MULTI_FILTER                  1
/** Index into current_action_spec::multi[] for server-header filters to apply. */
#define ACTION_MULTI_SERVER_HEADER_FILTER    2
/** Index into current_action_spec::multi[] for client-header filters to apply. */
#define ACTION_MULTI_CLIENT_HEADER_FILTER    3
/** Index into current_action_spec::multi[] for client-header tags to apply. */
#define ACTION_MULTI_CLIENT_HEADER_TAGGER    4
/** Index into current_action_spec::multi[] for server-header tags to apply. */
#define ACTION_MULTI_SERVER_HEADER_TAGGER    5
/** Number of multi-string actions. */
#define ACTION_MULTI_EXTERNAL_FILTER         6
/** Number of multi-string actions. */
#define ACTION_MULTI_COUNT                   7


/**
 * This structure contains a list of actions to apply to a URL.
 * It only contains positive instructions - no "-" options.
 * It is not used to store the actions list itself, only for
 * url_actions() to return the current values.
 */
struct current_action_spec
{
   /** Actions to apply.  A bit set to "1" means perform the action. */
   unsigned long flags;

   /**
    * Paramaters for those actions that require them.
    * Each entry is valid if & only if the corresponding entry in "flags" is
    * set.
    */
   char * string[ACTION_STRING_COUNT];

   /** Lists of strings for multi-string actions. */
   struct list multi[ACTION_MULTI_COUNT][1];
};


/**
 * This structure contains a set of changes to actions.
 * It can contain both positive and negative instructions.
 * It is used to store an entry in the actions list.
 */
struct action_spec
{
   unsigned long mask; /**< Actions to keep. A bit set to "0" means remove action. */
   unsigned long add;  /**< Actions to add.  A bit set to "1" means add action.    */

   /**
    * Parameters for those actions that require them.
    * Each entry is valid if & only if the corresponding entry in "flags" is
    * set.
    */
   char * string[ACTION_STRING_COUNT];

   /** Lists of strings to remove, for multi-string actions. */
   struct list multi_remove[ACTION_MULTI_COUNT][1];

   /** If nonzero, remove *all* strings from the multi-string action. */
   int         multi_remove_all[ACTION_MULTI_COUNT];

   /** Lists of strings to add, for multi-string actions. */
   struct list multi_add[ACTION_MULTI_COUNT][1];
};

enum forward_routing {
    ROUTE_NONE = 0,
    ROUTE_DIRECT,
    ROUTE_PROXY,
    ROUTE_BLOCK,
};


/**
 * This structure is used to store action files.
 *
 * It contains an URL or tag pattern, and the changes to
 * the actions. It's a linked list and should only be
 * free'd through unload_actions_file() unless there's
 * only a single entry.
 */
struct url_actions
{
    struct pattern_spec url[1]; /**< The URL or tag pattern. */

    char *rule;

    enum forward_routing routing;

    char *geoip;

    radix_tree_t *tree;

    struct action_spec *action; /**< Action settings that might be shared with
                                    the list entry before or after the current
                                    one and can't be free'd willy nilly. */

    struct url_actions *next;   /**< Next action section in file, or NULL. */
};

enum forwarder_type {
//   /**< Don't use a SOCKS server, forward to a HTTP proxy directly */
   SOCKS_NONE =  0,
   /**< original SOCKS 4 protocol              */
   SOCKS_4    = 40,
   /**< SOCKS 4A, DNS resolution is done by the SOCKS server */
   SOCKS_4A   = 41,
   /**< SOCKS 5 with hostnames, DNS resolution is done by the SOCKS server */
   SOCKS_5    = 50,
   /**< Like SOCKS5, but uses non-standard Tor extensions (currently only optimistic data) */
   SOCKS_5T,
   /**<
    * Don't use a SOCKS server, forward to the specified webserver.
    * The difference to SOCKS_NONE is that a request line without
    * full URL is sent.
    */
   FORWARD_WEBSERVER,
};

/*
 * Structure to hold the server socket and the information
 * required to make sure we only reuse the connection if
 * the host and forwarding settings are the same.
 */
struct reusable_connection
{
   jb_socket sfd;
   int       in_use;
   time_t    timestamp; /* XXX: rename? */

   time_t    request_sent;
   time_t    response_received;

   /*
    * Number of seconds after which this
    * connection will no longer be reused.
    */
   unsigned int keep_alive_timeout;
   /*
    * Number of requests that were sent to this connection.
    * This is currently only for debugging purposes.
    */
   unsigned int requests_sent_total;

   char *host;
   int  port;
   enum forwarder_type forwarder_type;
   char *gateway_host;
   int  gateway_port;
   char *forward_host;
   int  forward_port;
};


/*
 * Flags for use in csp->flags
 */

/**
 * Flag for csp->flags: Set if this client is processing data.
 * Cleared when the thread associated with this structure dies.
 */
#define CSP_FLAG_ACTIVE     0x01U

/**
 * Flag for csp->flags: Set if the server's reply is in "chunked"
 * transfer encoding
 */
#define CSP_FLAG_CHUNKED    0x02U

/**
 * Flag for csp->flags: Set if this request was enforced, although it would
 * normally have been blocked.
 */
#define CSP_FLAG_FORCED     0x04U

/**
 * Flag for csp->flags: Set if any modification to the body was done.
 */
#define CSP_FLAG_MODIFIED   0x08U

/**
 * Flag for csp->flags: Set if request was blocked.
 */
#define CSP_FLAG_REJECTED   0x10U

/**
 * Flag for csp->flags: Set if we are toggled on (FEATURE_TOGGLE).
 */
#define CSP_FLAG_TOGGLED_ON 0x20U

/**
 * Flag for csp->flags: Set if an acceptable Connection header
 * has already been set by the client.
 */
#define CSP_FLAG_CLIENT_CONNECTION_HEADER_SET  0x00000040U

/**
 * Flag for csp->flags: Set if an acceptable Connection header
 * has already been set by the server.
 */
#define CSP_FLAG_SERVER_CONNECTION_HEADER_SET  0x00000080U

/**
 * Flag for csp->flags: Signals header parsers whether they
 * are parsing server or client headers.
 */
#define CSP_FLAG_CLIENT_HEADER_PARSING_DONE    0x00000100U

/**
 * Flag for csp->flags: Set if adding the Host: header
 * isn't necessary.
 */
#define CSP_FLAG_HOST_HEADER_IS_SET            0x00000200U

/**
 * Flag for csp->flags: Set if filtering is disabled by X-Filter: No
 * XXX: As we now have tags we might as well ditch this.
 */
#define CSP_FLAG_NO_FILTERING                  0x00000400U

/**
 * Flag for csp->flags: Set the client IP has appended to
 * an already existing X-Forwarded-For header in which case
 * no new header has to be generated.
 */
#define CSP_FLAG_X_FORWARDED_FOR_APPENDED      0x00000800U

/**
 * Flag for csp->flags: Set if the server wants to keep
 * the connection alive.
 */
#define CSP_FLAG_SERVER_CONNECTION_KEEP_ALIVE  0x00001000U

/**
 * Flag for csp->flags: Set if the server specified the
 * content length.
 */
#define CSP_FLAG_SERVER_CONTENT_LENGTH_SET     0x00002000U

/**
 * Flag for csp->flags: Set if we know the content length,
 * either because the server set it, or we figured it out
 * on our own.
 */
#define CSP_FLAG_CONTENT_LENGTH_SET            0x00004000U

/**
 * Flag for csp->flags: Set if the client wants to keep
 * the connection alive.
 */
#define CSP_FLAG_CLIENT_CONNECTION_KEEP_ALIVE  0x00008000U

/**
 * Flag for csp->flags: Set if we think we got the whole
 * client request and shouldn't read any additional data
 * coming from the client until the current request has
 * been dealt with.
 */
#define CSP_FLAG_CLIENT_REQUEST_COMPLETELY_READ 0x00010000U

/**
 * Flag for csp->flags: Set if the server promised us to
 * keep the connection open for a known number of seconds.
 */
#define CSP_FLAG_SERVER_KEEP_ALIVE_TIMEOUT_SET  0x00020000U

/**
 * Flag for csp->flags: Set if we think we can't reuse
 * the server socket. XXX: It's also set after sabotaging
 * pipelining attempts which is somewhat inconsistent with
 * the name.
 */
#define CSP_FLAG_SERVER_SOCKET_TAINTED          0x00040000U

/**
 * Flag for csp->flags: Set if the Proxy-Connection header
 * is among the server headers.
 */
#define CSP_FLAG_SERVER_PROXY_CONNECTION_HEADER_SET 0x00080000U

/**
 * Flag for csp->flags: Set if the client reused its connection.
 */
#define CSP_FLAG_REUSED_CLIENT_CONNECTION           0x00100000U

/**
 * Flag for csp->flags: Set if the supports deflate compression.
 */
#define CSP_FLAG_CLIENT_SUPPORTS_DEFLATE            0x00200000U

/**
 * Flag for csp->flags: Set if the content has been deflated by Privoxy
 */
#define CSP_FLAG_BUFFERED_CONTENT_DEFLATED          0x00400000U

/**
 * Flag for csp->flags: Set if we already read (parts of)
 * a pipelined request in which case the client obviously
 * isn't done talking.
 */
#define CSP_FLAG_PIPELINED_REQUEST_WAITING          0x00800000U

/**
 * Flag for csp->flags: Set if the client body is chunk-encoded
 */
#define CSP_FLAG_CHUNKED_CLIENT_BODY                0x01000000U

/**
 * Flag for csp->flags: Set if the client set the Expect header
 */
#define CSP_FLAG_UNSUPPORTED_CLIENT_EXPECTATION     0x02000000U

/**
 * Flag for csp->flags: Set if we answered the request ourselve.
 */
#define CSP_FLAG_CRUNCHED                           0x04000000U

#define CSP_FLAG_LOG_REQUEST                        0x08000000U


/*
 * Flags for use in return codes of child processes
 */

/**
 * Flag for process return code: Set if exiting process has been toggled
 * during its lifetime.
 */
#define RC_FLAG_TOGGLED   0x10

/**
 * Flag for process return code: Set if exiting process has blocked its
 * request.
 */
#define RC_FLAG_BLOCKED   0x20

/**
 * Maximum number of actions/filter files.  This limit is arbitrary - it's just used
 * to size an array.
 */
#define MAX_AF_FILES 30

/**
 * Maximum number of sockets to listen to.  This limit is arbitrary - it's just used
 * to size an array.
 */
#define MAX_LISTENING_SOCKETS 10

enum time_stage {
    TIME_STAGE_INIT = 0,
    TIME_STAGE_CLOSED,
    TIME_STAGE_URL_RULE_MATCH_START,
    TIME_STAGE_URL_RULE_MATCH_END,
    TIME_STAGE_IP_RULE_MATCH_START,
    TIME_STAGE_IP_RULE_MATCH_END,
    TIME_STAGE_DNS_IP_RULE_MATCH_START,
    TIME_STAGE_DNS_IP_RULE_MATCH_END,

    TIME_STAGE_DNS_START,
    TIME_STAGE_DNS_FAIL,
    TIME_STAGE_DNS_END,
    TIME_STAGE_REMOTE_START,
    TIME_STAGE_REMOTE_CONNECTED,

    TIME_STAGE_GLOBAL_MODE,
    TIME_STAGE_NON_GLOBAL_MODE,

    TIME_STAGE_PROXY_DNS_START,
    TIME_STAGE_PROXY_DNS_FAIL,
    TIME_STAGE_PROXY_DNS_END,
    TIME_STAGE_PROXY_START,
    TIME_STAGE_PROXY_CONNECTED,

    TIME_STAGE_IPV6,

    TIME_STAGE_COUNT
};

enum forward_stage {
    FORWARD_STAGE_NONE = 0,
    FORWARD_STAGE_URL,
    FORWARD_STAGE_IP,
    FORWARD_STAGE_DNS_POLLUTION,
    FORWARD_STAGE_DNS_FAILURE,
};

/**
 * The state of a Privoxy processing thread.
 */
struct client_state
{
    /** The proxy's configuration */
    struct configuration_spec * config;

    /** The actions to perform on the current request */
    struct current_action_spec  action[1];

    /** socket to talk to client (web browser) */
    jb_socket cfd;

    /** Number of requests received on the client socket. */
    unsigned int requests_received_total;

    /** current connection to the server (may go through a proxy) */
    struct reusable_connection server_connection;

    /** Multi-purpose flag container, see CSP_FLAG_* above */
    unsigned int flags;

    /** Client PC's IP address, as reported by the accept() function.
       As a string. */
    char *ip_addr_str;
#ifdef HAVE_RFC2553
    /** Client PC's TCP address, as reported by the accept() function.
       As a sockaddr. */
    struct sockaddr_storage tcp_addr;
#else
    /** Client PC's IP address, as reported by the accept() function.
       As a number. */
    unsigned long ip_addr_long;
#endif /* def HAVE_RFC2553 */

    /** The URL that was requested */
    struct http_request http[1];

    // Time Logging
    enum time_stage current_time_stage;
    double time_stages[TIME_STAGE_COUNT];

    /*
    * The final forwarding settings.
    * XXX: Currently this is only used for forward-override,
    * so we can free the space in sweep.
    */
    struct forward_spec *fwd;
    enum forward_stage current_forward_stage;
    int is_ipv6;

    char *rule;

    enum forward_routing routing;

    int forward_determined;

    /** An I/O buffer used for buffering data read from the server */
    /* XXX: should be renamed to server_iob */
    struct iob iob[1];

    /** An I/O buffer used for buffering data read from the client */
    struct iob client_iob[1];

    /** List of all headers for this request */
    struct list headers[1];

    /** List of all tags that apply to this request */
    struct list tags[1];

    /** MIME-Type key, see CT_* above */
    unsigned int content_type;

    /** Actions files associated with this client */
    struct file_list *actions_list[MAX_AF_FILES];

    /** pcrs job files. */
    struct file_list *rlist[MAX_AF_FILES];

    /** Length after content modification. */
    unsigned long long content_length;

    /* XXX: is this the right location? */

    /** Expected length of content after which we
    * should stop reading from the server socket.
    */
    unsigned long long expected_content_length;

    /** Expected length of content after which we
    *  should stop reading from the client socket.
    */
    unsigned long long expected_client_content_length;

#ifdef FEATURE_TRUST

    /** Trust file. */
    struct file_list *tlist;

#endif /* def FEATURE_TRUST */

    /**
    * Failure reason to embedded in the CGI error page,
    * or NULL. Currently only used for socks errors.
    */
    char *error_message;
};

extern struct url_actions *po_url_rules;
extern struct url_actions *po_ip_rules;
extern struct url_actions *po_dns_ip_rules;
extern struct url_actions *po_dns_ip_rules_tail;

/**
 * List of client states so the main thread can keep
 * track of them and garbage collect their resources.
 */
struct client_states
{
   struct client_states *next;
   struct client_state csp;
};

struct log_client_states
{
    struct log_client_states *next;
    struct client_state *csp;
};

/**
 * A function to add a header
 */
typedef jb_err (*add_header_func_ptr)(struct client_state *);

/**
 * A function to process a header
 */
typedef jb_err (*parser_func_ptr    )(struct client_state *, char **);


/**
 * List of available CGI functions.
 */
struct cgi_dispatcher
{
   /** The URL of the CGI, relative to the CGI root. */
   const char * const name;

   /** The handler function for the CGI */
   jb_err    (* const handler)(struct client_state *csp, struct http_response *rsp, const struct map *parameters);

   /** The description of the CGI, to appear on the main menu, or NULL to hide it. */
   const char * const description;

   /** A flag that indicates whether unintentional calls to this CGI can cause damage */
   int harmless;
};


/**
 * A data file used by Privoxy.  Kept in a linked list.
 */
struct file_list
{
   /**
    * This is a pointer to the data structures associated with the file.
    * Read-only once the structure has been created.
    */
   void *f;

   /**
    * The unloader function.
    * Normally NULL.  When we are finished with file (i.e. when we have
    * loaded a new one), set to a pointer to an unloader function.
    * Unloader will be called by sweep() (called from main loop) when
    * all clients using this file are done.  This prevents threading
    * problems.
    */
   void (*unloader)(void *);

   /**
    * Used internally by sweep().  Do not access from elsewhere.
    */
   int active;

   /**
    * File last-modified time, so we can check if file has been changed.
    * Read-only once the structure has been created.
    */
   time_t lastmodified;

   /**
    * The full filename.
    */
   char * filename;

   /**
    * Pointer to next entry in the linked list of all "file_list"s.
    * This linked list is so that sweep() can navigate it.
    * Since sweep() can remove items from the list, we must be careful
    * to only access this value from main thread (when we know sweep
    * won't be running).
    */
   struct file_list *next;
};


#ifdef FEATURE_TRUST

/**
 * The format of a trust file when loaded into memory.
 */
struct block_spec
{
   struct pattern_spec url[1]; /**< The URL pattern              */
   int    reject;              /**< FIXME: Please document this! */
   struct block_spec *next;    /**< Next entry in linked list    */
};

/**
 * Arbitrary limit for the number of trusted referrers.
 */
#define MAX_TRUSTED_REFERRERS 512

#endif /* def FEATURE_TRUST */


/**
 * An IP address pattern.  Used to specify networks in the ACL.
 */
struct access_control_addr
{
#ifdef HAVE_RFC2553
    struct sockaddr_storage addr; /* <The TCP address in network order. */
    struct sockaddr_storage mask; /* <The TCP mask in network order. */
#else
    unsigned long addr;  /**< The IP address as an integer. */
    unsigned long mask;  /**< The network mask as an integer. */
    unsigned long port;  /**< The port number. */
#endif /* HAVE_RFC2553 */
};


/**
 * How to forward a connection to a parent proxy.
 */
struct forward_spec
{
    /** URL pattern that this forward_spec is for. */
    struct pattern_spec url[1];

    /** Connection type.  Must be SOCKS_NONE, SOCKS_4, SOCKS_4A or SOCKS_5. */
    enum forwarder_type type;

    /** SOCKS server hostname.  Only valid if "type" is SOCKS_4 or SOCKS_4A. */
    char *gateway_host;

    /** SOCKS server port. */
    int   gateway_port;

    /** Parent HTTP proxy hostname, or NULL for none. */
    char *forward_host;

    /** Parent HTTP proxy port. */
    int   forward_port;

    /** Next entry in the linked list. */
    struct forward_spec *next;

    int is_default;

    int should_unload;
};

extern struct forward_spec *proxy_list;

extern struct forward_spec fwd_default[1]; /* Zero'ed due to being static. */

/* Supported filter types */
enum filter_type
{
   FT_CONTENT_FILTER       = 0,
   FT_CLIENT_HEADER_FILTER = 1,
   FT_SERVER_HEADER_FILTER = 2,
   FT_CLIENT_HEADER_TAGGER = 3,
   FT_SERVER_HEADER_TAGGER = 4,
#ifdef FEATURE_EXTERNAL_FILTERS
   FT_EXTERNAL_CONTENT_FILTER = 5,
#endif
   FT_INVALID_FILTER       = 42,
};

#ifdef FEATURE_EXTERNAL_FILTERS
#define MAX_FILTER_TYPES        6
#else
#define MAX_FILTER_TYPES        5
#endif

/**
 * This struct represents one filter (one block) from
 * the re_filterfile. If there is more than one filter
 * in the file, the file will be represented by a
 * chained list of re_filterfile specs.
 */
struct re_filterfile_spec
{
   char *name;                      /**< Name from FILTER: statement in re_filterfile. */
   char *description;               /**< Description from FILTER: statement in re_filterfile. */
   struct list patterns[1];         /**< The patterns from the re_filterfile. */
   pcrs_job *joblist;               /**< The resulting compiled pcrs_jobs. */
   enum filter_type type;           /**< Filter type (content, client-header, server-header). */
   int dynamic;                     /**< Set to one if the pattern might contain variables
                                         and has to be recompiled for every request. */
   struct re_filterfile_spec *next; /**< The pointer for chaining. */
};


#ifdef FEATURE_ACL

#define ACL_PERMIT   1  /**< Accept connection request */
#define ACL_DENY     2  /**< Reject connection request */

/**
 * An access control list (ACL) entry.
 *
 * This is a linked list.
 */
struct access_control_list
{
   struct access_control_addr src[1];  /**< Client IP address */
   struct access_control_addr dst[1];  /**< Website or parent proxy IP address */
#ifdef HAVE_RFC2553
   int wildcard_dst;                   /** < dst address is wildcard */
#endif

   short action;                       /**< ACL_PERMIT or ACL_DENY */
   struct access_control_list *next;   /**< The next entry in the ACL. */
};

#endif /* def FEATURE_ACL */


/** Maximum number of loaders (actions, re_filter, ...) */
#define NLOADERS 8


/** configuration_spec::feature_flags: CGI actions editor. */
#define RUNTIME_FEATURE_CGI_EDIT_ACTIONS             1U

/** configuration_spec::feature_flags: Web-based toggle. */
#define RUNTIME_FEATURE_CGI_TOGGLE                   2U

/** configuration_spec::feature_flags: HTTP-header-based toggle. */
#define RUNTIME_FEATURE_HTTP_TOGGLE                  4U

/** configuration_spec::feature_flags: Split large forms to limit the number of GET arguments. */
#define RUNTIME_FEATURE_SPLIT_LARGE_FORMS            8U

/** configuration_spec::feature_flags: Check the host header for requests with host-less request lines. */
#define RUNTIME_FEATURE_ACCEPT_INTERCEPTED_REQUESTS 16U

/** configuration_spec::feature_flags: Don't allow to circumvent blocks with the force prefix. */
#define RUNTIME_FEATURE_ENFORCE_BLOCKS              32U

/** configuration_spec::feature_flags: Allow to block or redirect CGI requests. */
#define RUNTIME_FEATURE_CGI_CRUNCHING               64U

/** configuration_spec::feature_flags: Try to keep the connection to the server alive. */
#define RUNTIME_FEATURE_CONNECTION_KEEP_ALIVE      128U

/** configuration_spec::feature_flags: Share outgoing connections between different client connections. */
#define RUNTIME_FEATURE_CONNECTION_SHARING         256U

/** configuration_spec::feature_flags: Pages blocked with +handle-as-empty-doc get a return status of 200 OK. */
#define RUNTIME_FEATURE_EMPTY_DOC_RETURNS_OK       512U

/** configuration_spec::feature_flags: Buffered content is sent compressed if the client supports it. */
#define RUNTIME_FEATURE_COMPRESSION               1024U

/** configuration_spec::feature_flags: Pipelined requests are served instead of being discarded. */
#define RUNTIME_FEATURE_TOLERATE_PIPELINING       2048U

/** configuration_spec::feature_flags: Proxy authentication headers are forwarded instead of removed. */
#define RUNTIME_FEATURE_FORWARD_PROXY_AUTHENTICATION_HEADERS      4096U

/**
 * Data loaded from the configuration file.
 *
 * (Anomaly: toggle is still handled through a global, not this structure)
 */
struct configuration_spec
{
   /** What to log */
   int debug;

   /** Nonzero to enable multithreading. */
   int multi_threaded;

   /** Bitmask of features that can be controlled through the config file. */
   unsigned feature_flags;

   /** The log file name. */
   const char *logfile;

   /** The config file directory. */
   const char *confdir;

    /** The mmdbpath. */
    const char *mmdbpath;

   /** The directory for customized CGI templates. */
   const char *templdir;

#ifdef FEATURE_EXTERNAL_FILTERS
   /** The template used to create temporary files. */
   const char *temporary_directory;
#endif

   /** The log file directory. */
   const char *logdir;

   /** The full paths to the actions files. */
   const char *actions_file[MAX_AF_FILES];

   /** The short names of the actions files. */
   const char *actions_file_short[MAX_AF_FILES];

   /** The administrator's email address */
   char *admin_address;

   /** A URL with info on this proxy */
   char *proxy_info_url;

   /** URL to the user manual (on our website or local copy) */
   char *usermanual;

   /** The file names of the pcre filter files. */
   const char *re_filterfile[MAX_AF_FILES];

   /** The short names of the pcre filter files. */
   const char *re_filterfile_short[MAX_AF_FILES];

   /**< List of ordered client header names. */
   struct list ordered_client_headers[1];

   /** The hostname to show on CGI pages, or NULL to use the real one. */
   const char *hostname;

   /** IP addresses to bind to.  Defaults to HADDR_DEFAULT == 127.0.0.1. */
   const char *haddr[MAX_LISTENING_SOCKETS];

   /** Ports to bind to.  Defaults to HADDR_PORT == 8118. */
   int         hport[MAX_LISTENING_SOCKETS];

   /** Size limit for IOB */
   size_t buffer_limit;

#ifdef FEATURE_TRUST

   /** The file name of the trust file. */
   const char * trustfile;

   /** FIXME: DOCME: Document this. */
   struct list trust_info[1];

   /** FIXME: DOCME: Document this. */
   struct pattern_spec *trust_list[MAX_TRUSTED_REFERRERS];

#endif /* def FEATURE_TRUST */

#ifdef FEATURE_ACL

   /** The access control list (ACL). */
   struct access_control_list *acl;

#endif /* def FEATURE_ACL */

   /** Information about parent proxies (forwarding). */
   struct forward_spec *forward;

   /** Number of retries in case a forwarded connection attempt fails */
   int forwarded_connect_retries;

   /** Maximum number of client connections. */
   int max_client_connections;

   /* Timeout when waiting on sockets for data to become available. */
   int socket_timeout;

#ifdef FEATURE_CONNECTION_KEEP_ALIVE
   /* Maximum number of seconds after which an open connection will no longer be reused. */
   unsigned int keep_alive_timeout;

   /* Assumed server-side keep alive timeout if none is specified. */
   unsigned int default_server_timeout;
#endif

#ifdef FEATURE_COMPRESSION
   int compression_level;
#endif

   /** All options from the config file, HTML-formatted. */
   char *proxy_args;

   /** The configuration file object. */
   struct file_list *config_file_list;

   /** List of loaders */
   int (*loaders[NLOADERS])(struct client_state *);

};

extern int global_mode;

/** Calculates the number of elements in an array, using sizeof. */
#define SZ(X)  (sizeof(X) / sizeof(*X))

/** The force load URL prefix. Not behind an ifdef because
  * it's always used for the show-status page. */
#define FORCE_PREFIX "/PRIVOXY-FORCE"

#ifdef FEATURE_NO_GIFS
/** The MIME type for images ("image/png" or "image/gif"). */
#define BUILTIN_IMAGE_MIMETYPE "image/png"
#else
#define BUILTIN_IMAGE_MIMETYPE "image/gif"
#endif /* def FEATURE_NO_GIFS */


/*
 * Hardwired URLs
 */

/** URL for the Privoxy home page. */
#define HOME_PAGE_URL     "http://www.privoxy.org/"

/** URL for the Privoxy user manual. */
#define USER_MANUAL_URL   HOME_PAGE_URL VERSION "/user-manual/"

/** Prefix for actions help links  (append to USER_MANUAL_URL). */
#define ACTIONS_HELP_PREFIX "actions-file.html#"

/** Prefix for config option help links (append to USER_MANUAL_URL). */
#define CONFIG_HELP_PREFIX  "config.html#"

/*
 * The "hosts" to intercept and display CGI pages.
 * First one is a hostname only, second one can specify host and path.
 *
 * Notes:
 * 1) Do not specify the http: prefix
 * 2) CGI_SITE_2_PATH must not end with /, one will be added automatically.
 * 3) CGI_SITE_2_PATH must start with /, unless it is the empty string.
 */
#define CGI_SITE_1_HOST "p.p"
#define CGI_SITE_2_HOST "config.privoxy.org"
#define CGI_SITE_2_PATH ""

/**
 * The prefix for CGI pages.  Written out in generated HTML.
 * INCLUDES the trailing slash.
 */
#define CGI_PREFIX  "http://" CGI_SITE_2_HOST CGI_SITE_2_PATH "/"

#endif /* ndef PROJECT_H_INCLUDED */

/*
  Local Variables:
  tab-width: 3
  end:
*/
