#ifndef JBSOCKETS_H_INCLUDED
#define JBSOCKETS_H_INCLUDED
#define JBSOCKETS_H_VERSION "$Id: jbsockets.h,v 1.24 2014/06/02 06:22:20 fabiankeil Exp $"
/*********************************************************************
 *
 * File        :  $Source: /cvsroot/ijbswa/current/jbsockets.h,v $
 *
 * Purpose     :  Contains wrappers for system-specific sockets code,
 *                so that the rest of Junkbuster can be more
 *                OS-independent.  Contains #ifdefs to make this work
 *                on many platforms.
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


#include "project.h"

struct client_state;

extern jb_socket connect_to(const char *host, int portnum, struct client_state *csp, int is_proxy);
extern jb_socket connect_to_forward(struct client_state *csp, struct forward_spec *fwd, int is_proxy);
#ifdef AMIGA
extern int write_socket(jb_socket fd, const char *buf, ssize_t n);
#else
extern int write_socket(jb_socket fd, const char *buf, size_t n);
#endif
extern int read_socket(jb_socket fd, char *buf, int n);
extern int data_is_available(jb_socket fd, int seconds_to_wait);
extern void close_socket(jb_socket fd);
extern void drain_and_close_socket(jb_socket fd);

extern int bind_port(const char *hostnam, int portnum, jb_socket *pfd);
extern int accept_connection(struct client_state * csp, jb_socket fds[]);
extern void get_host_information(jb_socket afd, char **ip_address, char **port, char **hostname);

extern unsigned long resolve_hostname_to_ip(const char *host);

extern int socket_is_still_alive(jb_socket sfd);

#ifdef FEATURE_EXTERNAL_FILTERS
extern void mark_socket_for_close_on_execute(jb_socket fd);
#endif

/* Revision control strings from this header and associated .c file */
extern const char jbsockets_rcs[];
extern const char jbsockets_h_rcs[];

/*
 * Solaris workaround
 * XXX: still necessary?
 */
#ifndef INADDR_NONE
#define INADDR_NONE -1
#endif


#endif /* ndef JBSOCKETS_H_INCLUDED */

/*
  Local Variables:
  tab-width: 3
  end:
*/
