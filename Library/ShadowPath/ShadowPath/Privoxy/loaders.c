const char loaders_rcs[] = "$Id: loaders.c,v 1.100 2015/01/24 16:40:21 fabiankeil Exp $";
/*********************************************************************
 *
 * File        :  $Source: /cvsroot/ijbswa/current/loaders.c,v $
 *
 * Purpose     :  Functions to load and unload the various
 *                configuration files.  Also contains code to manage
 *                the list of active loaders, and to automatically
 *                unload files that are no longer in use.
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


#include "sp_config.h"

#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <string.h>
#include <errno.h>
#include <sys/stat.h>
#include <ctype.h>
#include <assert.h>

#if !defined(_WIN32) && !defined(__OS2__)
#include <unistd.h>
#endif

#include "project.h"
#include "list.h"
#include "loaders.h"
#include "filters.h"
#include "parsers.h"
#include "jcc.h"
#include "miscutil.h"
#include "errlog.h"
#include "actions.h"
#include "urlmatch.h"
#include "encode.h"

const char loaders_h_rcs[] = LOADERS_H_VERSION;

/*
 * Currently active files.
 * These are also entered in the main linked list of files.
 */

#ifdef FEATURE_TRUST
static struct file_list *current_trustfile      = NULL;
#endif /* def FEATURE_TRUST */

static int load_one_re_filterfile(struct client_state *csp, int fileid);

static struct file_list *current_re_filterfile[MAX_AF_FILES]  = {
   NULL, NULL, NULL, NULL, NULL,
   NULL, NULL, NULL, NULL, NULL
};


/*********************************************************************
 *
 * Function    :  sweep
 *
 * Description :  Basically a mark and sweep garbage collector, it is run
 *                (by the parent thread) every once in a while to reclaim memory.
 *
 * It uses a mark and sweep strategy:
 *   1) mark all files as inactive
 *
 *   2) check with each client:
 *       if it is active,   mark its files as active
 *       if it is inactive, free its resources
 *
 *   3) free the resources of all of the files that
 *      are still marked as inactive (and are obsolete).
 *
 *   N.B. files that are not obsolete don't have an unloader defined.
 *
 * Parameters  :  None
 *
 * Returns     :  The number of threads that are still active.
 *
 *********************************************************************/
unsigned int sweep(void)
{
   struct file_list *fl, *nfl;
   struct client_state *csp;
   struct client_states *last_active, *client_list;
   int i;
   unsigned int active_threads = 0;

   /* clear all of the file's active flags */
   for (fl = files->next; NULL != fl; fl = fl->next)
   {
      fl->active = 0;
   }

   last_active = clients;
   client_list = clients->next;

   while (NULL != client_list)
   {
      csp = &client_list->csp;
       if (!(csp->flags & CSP_FLAG_ACTIVE)) {
           log_time_stage(csp, TIME_STAGE_CLOSED);
       }
      if (csp->flags & (CSP_FLAG_ACTIVE | CSP_FLAG_LOG_REQUEST))
      {
         /* Mark this client's files as active */

         /*
          * Always have a configuration file.
          * (Also note the slightly non-standard extra
          * indirection here.)
          */
         csp->config->config_file_list->active = 1;

         /*
          * Actions files
          */
         for (i = 0; i < MAX_AF_FILES; i++)
         {
            if (csp->actions_list[i])
            {
               csp->actions_list[i]->active = 1;
            }
         }

         /*
          * Filter files
          */
         for (i = 0; i < MAX_AF_FILES; i++)
         {
            if (csp->rlist[i])
            {
               csp->rlist[i]->active = 1;
            }
         }

         /*
          * Trust file
          */
#ifdef FEATURE_TRUST
         if (csp->tlist)
         {
            csp->tlist->active = 1;
         }
#endif /* def FEATURE_TRUST */

         active_threads++;

         last_active = client_list;
         client_list = client_list->next;
      }
      else
      /*
       * This client is not active. Free its resources.
       */
      {
         last_active->next = client_list->next;

         freez(csp->ip_addr_str);
         freez(csp->client_iob->buf);
         freez(csp->iob->buf);
         freez(csp->error_message);
         freez(csp->rule);

         if (csp->action->flags & ACTION_FORWARD_OVERRIDE &&
             NULL != csp->fwd)
         {
            unload_forward_spec(csp->fwd);
         }
         free_http_request(csp->http);

         destroy_list(csp->headers);
         destroy_list(csp->tags);

         free_current_action(csp->action);

#ifdef FEATURE_STATISTICS
         urls_read++;
         if (csp->flags & CSP_FLAG_REJECTED)
         {
            urls_rejected++;
         }
#endif /* def FEATURE_STATISTICS */

         freez(client_list);

         client_list = last_active->next;
      }
   }

   nfl = files;
   fl = files->next;

   while (fl != NULL)
   {
      if ((0 == fl->active) && (NULL != fl->unloader))
      {
         nfl->next = fl->next;

         (fl->unloader)(fl->f);

         freez(fl->filename);
         freez(fl);

         fl = nfl->next;
      }
      else
      {
         nfl = fl;
         fl = fl->next;
      }
   }

   return active_threads;

}


/*********************************************************************
 *
 * Function    :  check_file_changed
 *
 * Description :  Helper function to check if a file needs reloading.
 *                If "current" is still current, return it.  Otherwise
 *                allocates a new (zeroed) "struct file_list", fills
 *                in the disk file name and timestamp, and returns it.
 *
 * Parameters  :
 *          1  :  current = The file_list currently being used - will
 *                          be checked to see if it is out of date.
 *                          May be NULL (which is treated as out of
 *                          date).
 *          2  :  filename = Name of file to check.
 *          3  :  newfl    = New file list. [Output only]
 *                           This will be set to NULL, OR a struct
 *                           file_list newly allocated on the
 *                           heap, with the filename and lastmodified
 *                           fields filled, and all others zeroed.
 *
 * Returns     :  If file unchanged: 0 (and sets newfl == NULL)
 *                If file changed: 1 and sets newfl != NULL
 *                On error: 1 and sets newfl == NULL
 *
 *********************************************************************/
int check_file_changed(const struct file_list * current,
                       const char * filename,
                       struct file_list ** newfl)
{
   struct file_list *fs;
   struct stat statbuf[1];

   *newfl = NULL;

   if (stat(filename, statbuf) < 0)
   {
      /* Error, probably file not found. */
      return 1;
   }

    // Temp Fix
    if (current) {
        return 0;
    }

   if (current
       && (current->lastmodified == statbuf->st_mtime)
       && (0 == strcmp(current->filename, filename)))
   {
      return 0;
   }

   fs = (struct file_list *)zalloc(sizeof(struct file_list));
   if (fs == NULL)
   {
      /* Out of memory error */
      return 1;
   }


   fs->filename = strdup(filename);
   fs->lastmodified = statbuf->st_mtime;

   if (fs->filename == NULL)
   {
      /* Out of memory error */
      freez (fs);
      return 1;
   }
   *newfl = fs;
   return 1;
}


/*********************************************************************
 *
 * Function    :  simple_read_line
 *
 * Description :  Read a single line from a file and return it.
 *                This is basically a version of fgets() that malloc()s
 *                it's own line buffer.  Note that the buffer will
 *                always be a multiple of BUFFER_SIZE bytes long.
 *                Therefore if you are going to keep the string for
 *                an extended period of time, you should probably
 *                strdup() it and free() the original, to save memory.
 *
 *
 * Parameters  :
 *          1  :  dest = destination for newly malloc'd pointer to
 *                line data.  Will be set to NULL on error.
 *          2  :  fp = File to read from
 *          3  :  newline = Standard for newlines in the file.
 *                Will be unchanged if it's value on input is not
 *                NEWLINE_UNKNOWN.
 *                On output, may be changed from NEWLINE_UNKNOWN to
 *                actual convention in file.
 *
 * Returns     :  JB_ERR_OK     on success
 *                JB_ERR_MEMORY on out-of-memory
 *                JB_ERR_FILE   on EOF.
 *
 *********************************************************************/
jb_err simple_read_line(FILE *fp, char **dest, int *newline)
{
   size_t len = 0;
   size_t buflen = BUFFER_SIZE;
   char * buf;
   char * p;
   int ch;
   int realnewline = NEWLINE_UNKNOWN;

   if (NULL == (buf = malloc(buflen)))
   {
      return JB_ERR_MEMORY;
   }

   p = buf;

/*
 * Character codes.  If you have a weird compiler and the following are
 * incorrect, you also need to fix NEWLINE() in loaders.h
 */
#define CHAR_CR '\r' /* ASCII 13 */
#define CHAR_LF '\n' /* ASCII 10 */

   for (;;)
   {
      ch = getc(fp);
      if (ch == EOF)
      {
         if (len > 0)
         {
            *p = '\0';
            *dest = buf;
            return JB_ERR_OK;
         }
         else
         {
            free(buf);
            *dest = NULL;
            return JB_ERR_FILE;
         }
      }
      else if (ch == CHAR_CR)
      {
         ch = getc(fp);
         if (ch == CHAR_LF)
         {
            if (*newline == NEWLINE_UNKNOWN)
            {
               *newline = NEWLINE_DOS;
            }
         }
         else
         {
            if (ch != EOF)
            {
               ungetc(ch, fp);
            }
            if (*newline == NEWLINE_UNKNOWN)
            {
               *newline = NEWLINE_MAC;
            }
         }
         *p = '\0';
         *dest = buf;
         if (*newline == NEWLINE_UNKNOWN)
         {
            *newline = realnewline;
         }
         return JB_ERR_OK;
      }
      else if (ch == CHAR_LF)
      {
         *p = '\0';
         *dest = buf;
         if (*newline == NEWLINE_UNKNOWN)
         {
            *newline = NEWLINE_UNIX;
         }
         return JB_ERR_OK;
      }
      else if (ch == 0)
      {
         *p = '\0';
         *dest = buf;
         return JB_ERR_OK;
      }

      *p++ = (char)ch;

      if (++len >= buflen)
      {
         buflen += BUFFER_SIZE;
         if (NULL == (p = realloc(buf, buflen)))
         {
            free(buf);
            return JB_ERR_MEMORY;
         }
         buf = p;
         p = buf + len;
      }
   }
}


/*********************************************************************
 *
 * Function    :  edit_read_line
 *
 * Description :  Read a single non-empty line from a file and return
 *                it.  Trims comments, leading and trailing whitespace
 *                and respects escaping of newline and comment char.
 *                Provides the line in 2 alternative forms: raw and
 *                preprocessed.
 *                - raw is the raw data read from the file.  If the
 *                  line is not modified, then this should be written
 *                  to the new file.
 *                - prefix is any comments and blank lines that were
 *                  read from the file.  If the line is modified, then
 *                  this should be written out to the file followed
 *                  by the modified data.  (If this string is non-empty
 *                  then it will have a newline at the end).
 *                - data is the actual data that will be parsed
 *                  further by appropriate routines.
 *                On EOF, the 3 strings will all be set to NULL and
 *                0 will be returned.
 *
 * Parameters  :
 *          1  :  fp = File to read from
 *          2  :  raw_out = destination for newly malloc'd pointer to
 *                raw line data.  May be NULL if you don't want it.
 *          3  :  prefix_out = destination for newly malloc'd pointer to
 *                comments.  May be NULL if you don't want it.
 *          4  :  data_out = destination for newly malloc'd pointer to
 *                line data with comments and leading/trailing spaces
 *                removed, and line continuation performed.  May be
 *                NULL if you don't want it.
 *          5  :  newline = Standard for newlines in the file.
 *                On input, set to value to use or NEWLINE_UNKNOWN.
 *                On output, may be changed from NEWLINE_UNKNOWN to
 *                actual convention in file.  May be NULL if you
 *                don't want it.
 *          6  :  line_number = Line number in file.  In "lines" as
 *                reported by a text editor, not lines containing data.
 *
 * Returns     :  JB_ERR_OK     on success
 *                JB_ERR_MEMORY on out-of-memory
 *                JB_ERR_FILE   on EOF.
 *
 *********************************************************************/
jb_err edit_read_line(FILE *fp,
                      char **raw_out,
                      char **prefix_out,
                      char **data_out,
                      int *newline,
                      unsigned long *line_number)
{
   char *p;          /* Temporary pointer   */
   char *linebuf;    /* Line read from file */
   char *linestart;  /* Start of linebuf, usually first non-whitespace char */
   int contflag = 0; /* Nonzero for line continuation - i.e. line ends '\' */
   int is_empty = 1; /* Flag if not got any data yet */
   char *raw    = NULL; /* String to be stored in raw_out    */
   char *prefix = NULL; /* String to be stored in prefix_out */
   char *data   = NULL; /* String to be stored in data_out   */
   int scrapnewline;    /* Used for (*newline) if newline==NULL */
   jb_err rval = JB_ERR_OK;

   assert(fp);
   assert(raw_out || data_out);
   assert(newline == NULL
       || *newline == NEWLINE_UNKNOWN
       || *newline == NEWLINE_UNIX
       || *newline == NEWLINE_DOS
       || *newline == NEWLINE_MAC);

   if (newline == NULL)
   {
      scrapnewline = NEWLINE_UNKNOWN;
      newline = &scrapnewline;
   }

   /* Set output parameters to NULL */
   if (raw_out)
   {
      *raw_out    = NULL;
   }
   if (prefix_out)
   {
      *prefix_out = NULL;
   }
   if (data_out)
   {
      *data_out   = NULL;
   }

   /* Set string variables to new, empty strings. */

   if (raw_out)
   {
      raw = strdup("");
      if (NULL == raw)
      {
         return JB_ERR_MEMORY;
      }
   }
   if (prefix_out)
   {
      prefix = strdup("");
      if (NULL == prefix)
      {
         freez(raw);
         return JB_ERR_MEMORY;
      }
   }
   if (data_out)
   {
      data = strdup("");
      if (NULL == data)
      {
         freez(raw);
         freez(prefix);
         return JB_ERR_MEMORY;
      }
   }

   /* Main loop.  Loop while we need more data & it's not EOF. */

   while ((contflag || is_empty)
       && (JB_ERR_OK == (rval = simple_read_line(fp, &linebuf, newline))))
   {
      if (line_number)
      {
         (*line_number)++;
      }
      if (raw)
      {
         string_append(&raw,linebuf);
         if (string_append(&raw,NEWLINE(*newline)))
         {
            freez(prefix);
            freez(data);
            free(linebuf);
            return JB_ERR_MEMORY;
         }
      }

      /* Line continuation? Trim escape and set flag. */
      p = linebuf + strlen(linebuf) - 1;
      contflag = ((*linebuf != '\0') && (*p == '\\'));
      if (contflag)
      {
         *p = '\0';
      }

      /* Trim leading spaces if we're at the start of the line */
      linestart = linebuf;
      assert(NULL != data);
      if (*data == '\0')
      {
         /* Trim leading spaces */
         while (*linestart && isspace((int)(unsigned char)*linestart))
         {
            linestart++;
         }
      }

      /* Handle comment characters. */
      p = linestart;
      while ((p = strchr(p, '#')) != NULL)
      {
         /* Found a comment char.. */
         if ((p != linebuf) && (*(p-1) == '\\'))
         {
            /* ..and it's escaped, left-shift the line over the escape. */
            char *q = p - 1;
            while ((*q = *(q + 1)) != '\0')
            {
               q++;
            }
            /* Now scan from just after the "#". */
         }
         else
         {
            /* Real comment.  Save it... */
            if (p == linestart)
            {
               /* Special case:  Line only contains a comment, so all the
                * previous whitespace is considered part of the comment.
                * Undo the whitespace skipping, if any.
                */
               linestart = linebuf;
               p = linestart;
            }
            if (prefix)
            {
               string_append(&prefix,p);
               if (string_append(&prefix, NEWLINE(*newline)))
               {
                  freez(raw);
                  freez(data);
                  free(linebuf);
                  return JB_ERR_MEMORY;
               }
            }

            /* ... and chop off the rest of the line */
            *p = '\0';
         }
      } /* END while (there's a # character) */

      /* Write to the buffer */
      if (*linestart)
      {
         is_empty = 0;
         if (data)
         {
            if (string_append(&data, linestart))
            {
               freez(raw);
               freez(prefix);
               free(linebuf);
               return JB_ERR_MEMORY;
            }
         }
      }

      free(linebuf);
   } /* END while(we need more data) */

   /* Handle simple_read_line() errors - ignore EOF */
   if ((rval != JB_ERR_OK) && (rval != JB_ERR_FILE))
   {
      freez(raw);
      freez(prefix);
      freez(data);
      return rval;
   }

   if (raw ? (*raw == '\0') : is_empty)
   {
      /* EOF and no data there.  (Definition of "data" depends on whether
       * the caller cares about "raw" or just "data").
       */

      freez(raw);
      freez(prefix);
      freez(data);

      return JB_ERR_FILE;
   }
   else
   {
      /* Got at least some data */

      /* Remove trailing whitespace */
      chomp(data);

      if (raw_out)
      {
         *raw_out    = raw;
      }
      else
      {
         freez(raw);
      }
      if (prefix_out)
      {
         *prefix_out = prefix;
      }
      else
      {
         freez(prefix);
      }
      if (data_out)
      {
         *data_out   = data;
      }
      else
      {
         freez(data);
      }
      return JB_ERR_OK;
   }
}


/*********************************************************************
 *
 * Function    :  read_config_line
 *
 * Description :  Read a single non-empty line from a file and return
 *                it.  Trims comments, leading and trailing whitespace
 *                and respects escaping of newline and comment char.
 *
 * Parameters  :
 *          1  :  fp = File to read from
 *          2  :  linenum = linenumber in file
 *          3  :  buf = Pointer to a pointer to set to the data buffer.
 *
 * Returns     :  NULL on EOF or error
 *                Otherwise, returns buf.
 *
 *********************************************************************/
char *read_config_line(FILE *fp, unsigned long *linenum, char **buf)
{
   jb_err err;
   err = edit_read_line(fp, NULL, NULL, buf, NULL, linenum);
   if (err)
   {
      if (err == JB_ERR_MEMORY)
      {
         log_error(LOG_LEVEL_FATAL, "Out of memory loading a config file");
      }
      *buf = NULL;
   }
   return *buf;
}


#ifdef FEATURE_TRUST
/*********************************************************************
 *
 * Function    :  unload_trustfile
 *
 * Description :  Unloads a trustfile.
 *
 * Parameters  :
 *          1  :  f = the data structure associated with the trustfile.
 *
 * Returns     :  N/A
 *
 *********************************************************************/
static void unload_trustfile(void *f)
{
   struct block_spec *cur = (struct block_spec *)f;
   struct block_spec *next;

   while (cur != NULL)
   {
      next = cur->next;

      free_pattern_spec(cur->url);
      free(cur);

      cur = next;
   }

}


#ifdef FEATURE_GRACEFUL_TERMINATION
/*********************************************************************
 *
 * Function    :  unload_current_trust_file
 *
 * Description :  Unloads current trust file - reset to state at
 *                beginning of program.
 *
 * Parameters  :  None
 *
 * Returns     :  N/A
 *
 *********************************************************************/
void unload_current_trust_file(void)
{
   if (current_trustfile)
   {
      current_trustfile->unloader = unload_trustfile;
      current_trustfile = NULL;
   }
}
#endif /* FEATURE_GRACEFUL_TERMINATION */


/*********************************************************************
 *
 * Function    :  load_trustfile
 *
 * Description :  Read and parse a trustfile and add to files list.
 *
 * Parameters  :
 *          1  :  csp = Current client state (buffers, headers, etc...)
 *
 * Returns     :  0 => Ok, everything else is an error.
 *
 *********************************************************************/
int load_trustfile(struct client_state *csp)
{
   FILE *fp;

   struct block_spec *b, *bl;
   struct pattern_spec **tl;

   char *buf = NULL;
   int reject, trusted;
   struct file_list *fs;
   unsigned long linenum = 0;
   int trusted_referrers = 0;

//    if (current_trustfile) {
//        csp->tlist = current_trustfile;
//        return(0);
//    }
   if (!check_file_changed(current_trustfile, csp->config->trustfile, &fs))
   {
      /* No need to load */
      csp->tlist = current_trustfile;
      return(0);
   }
   if (!fs)
   {
      goto load_trustfile_error;
   }

   fs->f = bl = (struct block_spec *)zalloc(sizeof(*bl));
   if (bl == NULL)
   {
      goto load_trustfile_error;
   }

   if ((fp = fopen(csp->config->trustfile, "r")) == NULL)
   {
      goto load_trustfile_error;
   }
   log_error(LOG_LEVEL_INFO, "Loading trust file: %s", csp->config->trustfile);

   tl = csp->config->trust_list;

   while (read_config_line(fp, &linenum, &buf) != NULL)
   {
      trusted = 0;
      reject  = 1;

      if (*buf == '+')
      {
         trusted = 1;
         *buf = '~';
      }

      if (*buf == '~')
      {
         char *p;
         char *q;

         reject = 0;
         p = buf;
         q = p+1;
         while ((*p++ = *q++) != '\0')
         {
            /* nop */
         }
      }

      /* skip blank lines */
      if (*buf == '\0')
      {
         freez(buf);
         continue;
      }

      /* allocate a new node */
      if ((b = zalloc(sizeof(*b))) == NULL)
      {
         fclose(fp);
         goto load_trustfile_error;
      }

      /* add it to the list */
      b->next  = bl->next;
      bl->next = b;

      b->reject = reject;

      /* Save the URL pattern */
      if (create_pattern_spec(b->url, buf))
      {
         fclose(fp);
         goto load_trustfile_error;
      }

      /*
       * save a pointer to URL's spec in the list of trusted URL's, too
       */
      if (trusted)
      {
         if (++trusted_referrers < MAX_TRUSTED_REFERRERS)
         {
            *tl++ = b->url;
         }
      }
      freez(buf);
   }

   if (trusted_referrers >= MAX_TRUSTED_REFERRERS)
   {
      /*
       * FIXME: ... after Privoxy 3.0.4 is out.
       */
       log_error(LOG_LEVEL_ERROR, "Too many trusted referrers. Current limit is %d, you are using %d.\n"
          "  Additional trusted referrers are treated like ordinary trusted URLs.\n"
          "  (You can increase this limit by changing MAX_TRUSTED_REFERRERS in project.h and recompiling).",
          MAX_TRUSTED_REFERRERS, trusted_referrers);
   }

   *tl = NULL;

   fclose(fp);

   /* the old one is now obsolete */
   if (current_trustfile)
   {
      current_trustfile->unloader = unload_trustfile;
   }

   fs->next    = files->next;
   files->next = fs;
   current_trustfile = fs;
   csp->tlist = fs;

   return(0);

load_trustfile_error:
   log_error(LOG_LEVEL_FATAL, "can't load trustfile '%s': %E",
      csp->config->trustfile);
   freez(buf);
   return(-1);

}
#endif /* def FEATURE_TRUST */


/*********************************************************************
 *
 * Function    :  unload_re_filterfile
 *
 * Description :  Unload the re_filter list by freeing all chained
 *                re_filterfile specs and their data.
 *
 * Parameters  :
 *          1  :  f = the data structure associated with the filterfile.
 *
 * Returns     :  N/A
 *
 *********************************************************************/
static void unload_re_filterfile(void *f)
{
   struct re_filterfile_spec *a, *b = (struct re_filterfile_spec *)f;

   while (b != NULL)
   {
      a = b->next;

      destroy_list(b->patterns);
      pcrs_free_joblist(b->joblist);
      freez(b->name);
      freez(b->description);
      freez(b);

      b = a;
   }

   return;
}

/*********************************************************************
 *
 * Function    :  unload_forward_spec
 *
 * Description :  Unload the forward spec settings by freeing all
 *                memory referenced by members and the memory for
 *                the spec itself.
 *
 * Parameters  :
 *          1  :  fwd = the forward spec.
 *
 * Returns     :  N/A
 *
 *********************************************************************/
void unload_forward_spec(struct forward_spec *fwd)
{
   free_pattern_spec(fwd->url);
   freez(fwd->gateway_host);
   freez(fwd->forward_host);
   free(fwd);

   return;
}

void unload_forward_ip_spec(struct forward_spec *fwd)
{
    freez(fwd->gateway_host);
    freez(fwd->forward_host);
    free(fwd);

    return;
}


#ifdef FEATURE_GRACEFUL_TERMINATION
/*********************************************************************
 *
 * Function    :  unload_current_re_filterfile
 *
 * Description :  Unloads current re_filter file - reset to state at
 *                beginning of program.
 *
 * Parameters  :  None
 *
 * Returns     :  N/A
 *
 *********************************************************************/
void unload_current_re_filterfile(void)
{
   int i;

   for (i = 0; i < MAX_AF_FILES; i++)
   {
      if (current_re_filterfile[i])
      {
         current_re_filterfile[i]->unloader = unload_re_filterfile;
         current_re_filterfile[i] = NULL;
      }
   }
}
#endif


/*********************************************************************
 *
 * Function    :  load_re_filterfiles
 *
 * Description :  Loads all the filterfiles.
 *                Generate a chained list of re_filterfile_spec's from
 *                the "FILTER: " blocks, compiling all their substitutions
 *                into chained lists of pcrs_job structs.
 *
 * Parameters  :
 *          1  :  csp = Current client state (buffers, headers, etc...)
 *
 * Returns     :  0 => Ok, everything else is an error.
 *
 *********************************************************************/
int load_re_filterfiles(struct client_state *csp)
{
   int i;
   int result;

   for (i = 0; i < MAX_AF_FILES; i++)
   {
      if (csp->config->re_filterfile[i])
      {
         result = load_one_re_filterfile(csp, i);
         if (result)
         {
            return result;
         }
      }
      else if (current_re_filterfile[i])
      {
         current_re_filterfile[i]->unloader = unload_re_filterfile;
         current_re_filterfile[i] = NULL;
      }
   }

   return 0;
}


/*********************************************************************
 *
 * Function    :  load_one_re_filterfile
 *
 * Description :  Load a re_filterfile.
 *                Generate a chained list of re_filterfile_spec's from
 *                the "FILTER: " blocks, compiling all their substitutions
 *                into chained lists of pcrs_job structs.
 *
 * Parameters  :
 *          1  :  csp = Current client state (buffers, headers, etc...)
 *
 * Returns     :  0 => Ok, everything else is an error.
 *
 *********************************************************************/
int load_one_re_filterfile(struct client_state *csp, int fileid)
{
   FILE *fp;

   struct re_filterfile_spec *new_bl, *bl = NULL;
   struct file_list *fs;

   char *buf = NULL;
   int error;
   unsigned long linenum = 0;
   pcrs_job *dummy, *lastjob = NULL;

//    if (current_re_filterfile[fileid]) {
//        csp->rlist[fileid] = current_re_filterfile[fileid];
//        return(0);
//    }
   /*
    * No need to reload if unchanged
    */
   if (!check_file_changed(current_re_filterfile[fileid], csp->config->re_filterfile[fileid], &fs))
   {
      csp->rlist[fileid] = current_re_filterfile[fileid];
      return(0);
   }
   if (!fs)
   {
      goto load_re_filterfile_error;
   }

   /*
    * Open the file or fail
    */
   if ((fp = fopen(csp->config->re_filterfile[fileid], "r")) == NULL)
   {
      goto load_re_filterfile_error;
   }

   log_error(LOG_LEVEL_INFO, "Loading filter file: %s", csp->config->re_filterfile[fileid]);

   /*
    * Read line by line
    */
   while (read_config_line(fp, &linenum, &buf) != NULL)
   {
      enum filter_type new_filter = FT_INVALID_FILTER;

      if (strncmp(buf, "FILTER:", 7) == 0)
      {
         new_filter = FT_CONTENT_FILTER;
      }
      else if (strncmp(buf, "SERVER-HEADER-FILTER:", 21) == 0)
      {
         new_filter = FT_SERVER_HEADER_FILTER;
      }
      else if (strncmp(buf, "CLIENT-HEADER-FILTER:", 21) == 0)
      {
         new_filter = FT_CLIENT_HEADER_FILTER;
      }
      else if (strncmp(buf, "CLIENT-HEADER-TAGGER:", 21) == 0)
      {
         new_filter = FT_CLIENT_HEADER_TAGGER;
      }
      else if (strncmp(buf, "SERVER-HEADER-TAGGER:", 21) == 0)
      {
         new_filter = FT_SERVER_HEADER_TAGGER;
      }
#ifdef FEATURE_EXTERNAL_FILTERS
      else if (strncmp(buf, "EXTERNAL-FILTER:", 16) == 0)
      {
         new_filter = FT_EXTERNAL_CONTENT_FILTER;
      }
#endif

      /*
       * If this is the head of a new filter block, make it a
       * re_filterfile spec of its own and chain it to the list:
       */
      if (new_filter != FT_INVALID_FILTER)
      {
         new_bl = (struct re_filterfile_spec  *)zalloc(sizeof(*bl));
         if (new_bl == NULL)
         {
            goto load_re_filterfile_error;
         }
         if (new_filter == FT_CONTENT_FILTER)
         {
            new_bl->name = chomp(buf + 7);
         }
#ifdef FEATURE_EXTERNAL_FILTERS
         else if (new_filter == FT_EXTERNAL_CONTENT_FILTER)
         {
            new_bl->name = chomp(buf + 16);
         }
#endif
         else
         {
            new_bl->name = chomp(buf + 21);
         }
         new_bl->type = new_filter;

         /*
          * If a filter description is available,
          * encode it to HTML and save it.
          */
         if (NULL != (new_bl->description = strpbrk(new_bl->name, " \t")))
         {
            *new_bl->description++ = '\0';
            new_bl->description = html_encode(chomp(new_bl->description));
            if (NULL == new_bl->description)
            {
               new_bl->description = strdup("Out of memory while encoding this filter's description to HTML");
            }
         }
         else
         {
            new_bl->description = strdup("No description available for this filter");
         }

         new_bl->name = strdup(chomp(new_bl->name));

         /*
          * If this is the first filter block, chain it
          * to the file_list rather than its (nonexistant)
          * predecessor
          */
         if (fs->f == NULL)
         {
            fs->f = new_bl;
         }
         else
         {
            assert(NULL != bl);
            bl->next = new_bl;
         }
         bl = new_bl;

         log_error(LOG_LEVEL_RE_FILTER, "Reading in filter \"%s\" (\"%s\")", bl->name, bl->description);

         freez(buf);
         continue;
      }

#ifdef FEATURE_EXTERNAL_FILTERS
      if ((bl != NULL) && (bl->type == FT_EXTERNAL_CONTENT_FILTER))
      {
         /* Save the code as "pattern", but do not compile anything. */
         if (bl->patterns->first != NULL)
         {
            log_error(LOG_LEVEL_FATAL, "External filter '%s' contains several jobss. "
               "Did you forget to escape a line break?",
               bl->name);
         }
         error = enlist(bl->patterns, buf);
         if (JB_ERR_MEMORY == error)
         {
            log_error(LOG_LEVEL_FATAL,
               "Out of memory while enlisting external filter code \'%s\' for filter %s.",
               buf, bl->name);
         }
         freez(buf);
         continue;
      }
#endif
      if (bl != NULL)
      {
         /*
          * Save the expression, make it a pcrs_job
          * and chain it into the current filter's joblist
          */
         error = enlist(bl->patterns, buf);
         if (JB_ERR_MEMORY == error)
         {
            log_error(LOG_LEVEL_FATAL,
               "Out of memory while enlisting re_filter job \'%s\' for filter %s.", buf, bl->name);
         }
         assert(JB_ERR_OK == error);

         if (pcrs_job_is_dynamic(buf))
         {
            /*
             * Dynamic pattern that might contain variables
             * and has to be recompiled for every request
             */
            if (bl->joblist != NULL)
            {
                pcrs_free_joblist(bl->joblist);
                bl->joblist = NULL;
            }
            bl->dynamic = 1;
            log_error(LOG_LEVEL_RE_FILTER,
               "Adding dynamic re_filter job \'%s\' to filter %s succeeded.", buf, bl->name);
            freez(buf);
            continue;
         }
         else if (bl->dynamic)
         {
            /*
             * A previous job was dynamic and as we
             * recompile the whole filter anyway, it
             * makes no sense to compile this job now.
             */
            log_error(LOG_LEVEL_RE_FILTER,
               "Adding static re_filter job \'%s\' to dynamic filter %s succeeded.", buf, bl->name);
            freez(buf);
            continue;
         }

         if ((dummy = pcrs_compile_command(buf, &error)) == NULL)
         {
            log_error(LOG_LEVEL_ERROR,
               "Adding re_filter job \'%s\' to filter %s failed: %s",
               buf, bl->name, pcrs_strerror(error));
            freez(buf);
            continue;
         }
         else
         {
            if (bl->joblist == NULL)
            {
               bl->joblist = dummy;
            }
            else if (NULL != lastjob)
            {
               lastjob->next = dummy;
            }
            lastjob = dummy;
            log_error(LOG_LEVEL_RE_FILTER, "Adding re_filter job \'%s\' to filter %s succeeded.", buf, bl->name);
         }
      }
      else
      {
         log_error(LOG_LEVEL_ERROR, "Ignoring job %s outside filter block in %s, line %d",
            buf, csp->config->re_filterfile[fileid], linenum);
      }
      freez(buf);
   }

   fclose(fp);

   /*
    * Schedule the now-obsolete old data for unloading
    */
   if (NULL != current_re_filterfile[fileid])
   {
      current_re_filterfile[fileid]->unloader = unload_re_filterfile;
   }

   /*
    * Chain this file into the global list of loaded files
    */
   fs->next    = files->next;
   files->next = fs;
   current_re_filterfile[fileid] = fs;
   csp->rlist[fileid] = fs;

   return(0);

load_re_filterfile_error:
   log_error(LOG_LEVEL_FATAL, "can't load re_filterfile '%s': %E",
             csp->config->re_filterfile[fileid]);
   return(-1);

}


/*********************************************************************
 *
 * Function    :  add_loader
 *
 * Description :  Called from `load_config'.  Called once for each input
 *                file found in config.
 *
 * Parameters  :
 *          1  :  loader = pointer to a function that can parse and load
 *                the appropriate config file.
 *          2  :  config = The configuration_spec to add the loader to.
 *
 * Returns     :  N/A
 *
 *********************************************************************/
void add_loader(int (*loader)(struct client_state *),
                struct configuration_spec * config)
{
   int i;

   for (i = 0; i < NLOADERS; i++)
   {
      if (config->loaders[i] == NULL)
      {
         config->loaders[i] = loader;
         break;
      }
   }

}


/*********************************************************************
 *
 * Function    :  run_loader
 *
 * Description :  Called from `load_config' and `listen_loop'.  This
 *                function keeps the "csp" current with any file mods
 *                since the last loop.  If a file is unchanged, the
 *                loader functions do NOT reload the file.
 *
 * Parameters  :
 *          1  :  csp = Current client state (buffers, headers, etc...)
 *                      Must be non-null.  Reads: "csp->config"
 *                      Writes: various data members.
 *
 * Returns     :  0 => Ok, everything else is an error.
 *
 *********************************************************************/
int run_loader(struct client_state *csp)
{
   int ret = 0;
   int i;

   for (i = 0; i < NLOADERS; i++)
   {
      if (csp->config->loaders[i] == NULL)
      {
         break;
      }
      ret |= (csp->config->loaders[i])(csp);
   }
   return(ret);

}

/*********************************************************************
 *
 * Function    :  file_has_been_modified
 *
 * Description :  Helper function to check if a file has been changed
 *
 * Parameters  :
 *          1  : filename = The name of the file to check
 *          2  : last_known_modification = The time of the last known
 *                                         modification
 *
 * Returns     :  TRUE if the file has been changed,
 *                FALSE otherwise.
 *
 *********************************************************************/
static int file_has_been_modified(const char *filename, time_t last_know_modification)
{
   struct stat statbuf[1];

   if (stat(filename, statbuf) < 0)
   {
      /* Error, probably file not found which counts as change. */
      return 1;
   }

   return (last_know_modification != statbuf->st_mtime);
}


/*********************************************************************
 *
 * Function    :  any_loaded_file_changed
 *
 * Description :  Helper function to check if any loaded file has been
 *                changed since the time it has been loaded.
 *
 *                XXX: Should we cache the return value for x seconds?
 *
 * Parameters  :
 *          1  : files_to_check = List of files to check
 *
 * Returns     : TRUE if any file has been changed,
 *               FALSE otherwise.
 *
 *********************************************************************/
int any_loaded_file_changed(const struct client_state *csp)
{
   const struct file_list *file_to_check = csp->config->config_file_list;
   int i;

   if (file_has_been_modified(file_to_check->filename, file_to_check->lastmodified))
   {
      return TRUE;
   }

   for (i = 0; i < MAX_AF_FILES; i++)
   {
      if (csp->actions_list[i])
      {
         file_to_check = csp->actions_list[i];
         if (file_has_been_modified(file_to_check->filename, file_to_check->lastmodified))
         {
            return TRUE;
         }
      }
   }

   for (i = 0; i < MAX_AF_FILES; i++)
   {
      if (csp->rlist[i])
      {
         file_to_check = csp->rlist[i];
         if (file_has_been_modified(file_to_check->filename, file_to_check->lastmodified))
         {
            return TRUE;
         }
      }
   }

#ifdef FEATURE_TRUST
   if (csp->tlist)
   {
      if (file_has_been_modified(csp->tlist->filename, csp->tlist->lastmodified))
      {
         return TRUE;
      }
   }
#endif /* def FEATURE_TRUST */

   return FALSE;
}


/*
  Local Variables:
  tab-width: 3
  end:
*/
