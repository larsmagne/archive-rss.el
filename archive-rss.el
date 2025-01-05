;;; archive-rss.el --- Create an RSS feed from archive.org uploads -*- lexical-binding: t -*-

;; Copyright (C) 2025 Free Software Foundation, Inc.

;; Author: Lars Magne Ingebrigtsen <larsi@gnus.org>

;; archive-rss is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; archive-rss is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
;; or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
;; License for more details.

;;; Commentary:

;;; Code:

(require 'cl-lib)
(require 'xml)
(require 'message)
(require 'iso8601)

(defun archive-rss--fetch (query)
  (with-current-buffer (url-retrieve-synchronously
			(concat "https://archive.org/services/search/beta/page_production/?user_query="
				query
				"&hits_per_page=100&page=1&filter_map=%7B%22mediatype%22%3A%7B%22texts%22%3A%22inc%22%7D%7D&sort=addeddate%3Adesc&aggregations=false&uid=R%3Ab7684b722de3414a968d-S%3Aa487428fc9e0df6ed005-P%3A1-K%3Ah-T%3A1736113973501")
			nil t 60)
    (goto-char (point-min))
    (unwind-protect
	(and (search-forward "\n\n")
	     (json-parse-buffer))
      (kill-buffer (current-buffer)))))

(defun archive-rss--make-items (json)
  (cl-loop for item across
	   (gethash "hits"
		    (gethash "hits"
			     (gethash "body" (gethash "response" json))))
	   for fields = (gethash "fields" item)
	   collect
	   (list 'item
		 nil
		 (list 'title nil (gethash "title" fields))
		 (list 'description nil
		       (format "%s<p>\n<img src=%S>\n"
			       (gethash "description" fields)
			       (format "https://archive.org/services/img/%s"
				       (gethash "identifier" fields))))
		 (list 'pubDate nil
		       (message-make-date
			(encode-time
			 (iso8601-parse (gethash "addeddate" fields)))))
		 (list 'link nil
		       (format "https://archive.org/details/%s"
			       (gethash "identifier" fields))))))

(defun archive-rss--make-rss (json)
  (list
   (list
    'rss
    '((version . "2.0"))
    (append
     (list 'channel nil
	   (list 'title nil "archive.org feed")
	   (list 'link nil "https://quimby.gnus.org/circus/archive-rss/archive.rss")
	   (list 'last-build-date nil (message-make-date)))
     (archive-rss--make-items json)))))

(defun archive-rss (output-file)
  (with-temp-buffer
    (insert "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
    (xml-print (archive-rss--make-rss
		(archive-rss--fetch "(magazine OR comics OR fanzine)")))
    (write-region (point-min) (point-max) output-file)))

(provide 'archive-rss)

;;; archive-rss.el ends here
