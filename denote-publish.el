;;; denote-publish.el --- Publish denote files to markdown -*- lexical-binding: t; -*-

;; Copyright (C) 2024 Vedang Manerikar

;; Author: Vedang Manerikar <vedang.manerikar@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (denote "3.1") (ox-gfm))
;; Keywords: hypermedia, text, denote
;; URL: https://github.com/vedang/denote-publish

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This package provides functionality to publish Denote files as markdown files
;; with YAML front-matter.  It extends the GitHub Flavored Markdown export backend
;; to handle Denote-specific elements and adds customizable front-matter support.

;; Usage:
;;
;; 1. Customize the variables as needed:
;;    M-x customize-group RET denote-publish RET
;;
;; 2. Set up your publishing project:
;;    (setq org-publish-project-alist
;;          '(("my-denotes"
;;             :base-directory "~/notes/published"
;;             :publishing-directory "~/blog/content"
;;             :publishing-function denote-publish-to-md
;;             :recursive nil
;;             :exclude-tags ("noexport" "draft")
;;             :section-numbers nil
;;             :with-creator nil
;;             :with-toc nil)))
;;
;; 3. Publish your files:
;;    M-x org-publish RET my-denotes RET

;;; Code:

(require 'ox-publish)
(require 'ox-md)
(require 'ox-gfm)
(require 'denote)

(defgroup denote-publish nil
  "Customization options for denote-publish."
  :group 'denote
  :prefix "denote-publish-")

(defcustom denote-publish-default-base-dir (expand-file-name "~/notes")
  "Default base directory for Denote files to be published."
  :type 'directory
  :group 'denote-publish)

(defcustom denote-publish-default-output-dir (expand-file-name "~/blog/content")
  "Default output directory for published markdown files."
  :type 'directory
  :group 'denote-publish)

(defcustom denote-publish-link-class "internal-link"
  "CSS class to be applied to denote links in published markdown."
  :type 'string
  :group 'denote-publish)

(defcustom denote-publish-front-matter-fields
  '(title subtitle identifier date last_updated_at aliases tags category
          skip_archive has_code og_image og_description og_video_id)
  "List of fields to include in the YAML front matter.
Each element should be a symbol representing a field name."
  :type '(repeat symbol)
  :group 'denote-publish)

;; Internal variables
(defvar denote-publish--date-time-regexp
  (concat "\\`[[:digit:]]\\{4\\}-[[:digit:]]\\{2\\}-[[:digit:]]\\{2\\}"
          "\\(?:T[[:digit:]]\\{2\\}:[[:digit:]]\\{2\\}:[[:digit:]]\\{2\\}"
          "\\(?:Z\\|[+-][[:digit:]]\\{2\\}:[[:digit:]]\\{2\\}\\)*\\)*\\'")
  "Regexp to match RFC3339 timestamp strings.")

;; Define the export backend
(org-export-define-derived-backend 'denote-publish 'gfm
  :translate-alist
  '((link . denote-publish-link))
  :options-alist
  '((:with-drawers nil nil nil t)
    (:aliases "ALIASES" nil nil t)
    (:subtitle "SUBTITLE" nil nil t)
    (:identifier "IDENTIFIER" nil nil t)
    (:skip_archive "SKIP_ARCHIVE" nil nil t)
    (:has_code "HAS_CODE" nil nil t)
    (:og_image "OG_IMAGE" nil nil t)
    (:og_description "OG_DESCRIPTION" nil nil t)
    (:og_video_id "OG_VIDEO_ID" nil nil t)))

;; Front matter generation functions
(defun denote-publish--yaml-quote-string (val)
  "Wrap VAL with quotes according to YAML syntax rules.
VAL can be a string, symbol, number or nil.

VAL is returned as-it-is under the following cases:
- It is a number.
- It is a string and is already wrapped with double quotes.
- It is a string and it's value is \"true\" or \"false\".
- It is a string representing a date.
- It is a string representing an integer or float.

If VAL is nil or an empty string, a quoted empty string \"\" is
returned."
  (cond
   ((null val) val)
   ((numberp val) val)
   ((symbolp val) (format "\"%s\"" (symbol-name val)))
   ;; If `val' is a non-empty string
   ((org-string-nw-p val)
    (if (or (and (string= (substring val 0 1) "\"") ;First char is literally a "
                 (string= (substring val -1) "\"")) ;Last char is literally a "
            (string= "true" val)
            (string= "false" val)
            ;; or if it is a date (date, publishDate, expiryDate, lastmod)
            (string-match-p denote-publish--date-time-regexp val))
        val
      ;; Escape the backslashes
      (setq val (replace-regexp-in-string "\\\\" "\\\\\\\\" val))
      ;; Escape the double-quotes
      (setq val (replace-regexp-in-string "\"" "\\\\\""  val))
      (concat "\"" val "\"")))
   ;; Return empty string if anything else
   (t "\"\"")))

(defun denote-publish--get-yaml-list-string (key list)
  "Return KEY's LIST value as a YAML list string."
  (concat "["
          (mapconcat #'identity
                     (mapcar (lambda (v)
                               (denote-publish--yaml-quote-string
                                (cond
                                 ((symbolp v) (symbol-name v))
                                 ((numberp v) (number-to-string v))
                                 ((org-string-nw-p v) v)
                                 (t (user-error "Invalid element %S in `%s' value %S"
                                                v key list)))))
                             list)
                     ", ")
          "]"))

(defun denote-publish--gen-yaml-front-matter (data)
  "Generate YAML front matter string from DATA alist.

DATA is an alist of the form \((KEY1 . VAL1) (KEY2 . VAL2) .. \),
where KEY is a symbol and VAL is a string."
  (let ((sep "---\n")
        (front-matter ""))
    (dolist (pair data)
      (let ((key (symbol-name (car pair)))
            (value (cdr pair)))
        (unless (or (null value) (and (stringp value) (string= "" value)))
          (setq front-matter
                (concat front-matter
                        (format "%s: %s\n"
                                key
                                (if (listp value)
                                    (denote-publish--get-yaml-list-string key value)
                                  (denote-publish--yaml-quote-string value))))))))
    (concat sep front-matter sep)))

(defun denote-publish--get-front-matter (info)
  "Generate front matter string from export INFO plist."
  (let* ((front-matter-data
          (mapcar (lambda (field)
                    (cons field
                          (pcase field
                            ('title (car (plist-get info :title)))
                            ('date (org-export-get-date info "%Y-%m-%d"))
                            ('last_updated_at (format-time-string "%Y-%m-%d"))
                            ('aliases (when-let ((als (plist-get info :aliases)))
                                        (org-split-string als " ")))
                            ('tags org-file-tags)
                            ;; See: [ref: do_not_use_org-export-get-category]
                            ('category (org-element-map
                                           (plist-get info :parse-tree) 'keyword
                                         (lambda (kwd)
                                           (when (equal (org-element-property :key kwd)
                                                        "CATEGORY")
                                             (org-element-property :value kwd)))
                                         info 'first-match))
                            (_ (plist-get info (intern (downcase (symbol-name field))))))))
                  denote-publish-front-matter-fields)))
    (denote-publish--gen-yaml-front-matter front-matter-data)))

;; Link handling
(defun denote-publish--link-ol-export (link description)
  "Export a denote LINK with optional DESCRIPTION to HTML format."
  (let* ((path-id (denote-link--ol-resolve-link-to-target
                   (org-element-property :path link)
                   :full-data))
         (id (nth 1 path-id))
         (query (nth 2 path-id))
         (path (concat "denote:" id))
         (desc (cond
                (description)
                (query (format "%s::%s" id query))
                (t id))))
    (if query
        (format "<a href=\"%s.html%s\" class=\"%s\">%s</a>"
                path query denote-publish-link-class desc)
      (format "<a href=\"%s.html\" class=\"%s\">%s</a>"
              path denote-publish-link-class desc))))

(defun denote-publish-link (link desc info)
  "Convert LINK to Markdown format with DESC and INFO.
Handles denote: links specially, deferring to org-md-link for others."
  (let ((type (org-element-property :type link)))
    (if (equal type "denote")
        (denote-publish--link-ol-export link desc)
      (org-md-link link desc info))))

;; Publishing functions
(defun denote-publish-get-front-matter (filename)
  "Get the front matter string for FILENAME."
  (let* ((org-inhibit-startup t)
         (visiting (find-buffer-visiting filename))
         (work-buffer (or visiting (find-file-noselect filename))))
    (unwind-protect
        (with-current-buffer work-buffer
          (let* ((ast (org-element-parse-buffer))
                 (info (org-combine-plists
                        (list :parse-tree ast)
                        (org-export--get-export-attributes 'denote-publish)
                        (org-export-get-environment 'denote-publish))))
            (denote-publish--get-front-matter info)))
      (unless visiting (kill-buffer work-buffer)))))

;;;###autoload
(defun denote-publish-to-md (plist filename pub-dir)
  "Publish an org file to markdown with front matter.
PLIST is the project property list, FILENAME is the source org file,
and PUB-DIR is the publishing directory."
  (let ((fm (denote-publish-get-front-matter filename))
        (outfile (org-publish-org-to 'denote-publish
                                     filename
                                     ".md"
                                     plist
                                     pub-dir)))
    (with-temp-buffer
      (insert fm)
      (insert-file-contents outfile)
      (write-file outfile))
    outfile))

;;;###autoload
(defun denote-publish-file (file &optional output-dir)
  "Publish a single denote FILE to OUTPUT-DIR.
If OUTPUT-DIR is nil, use `denote-publish-default-output-dir'."
  (interactive "fSelect Denote file to publish: ")
  (let ((pub-dir (or output-dir denote-publish-default-output-dir)))
    (unless (file-exists-p pub-dir)
      (make-directory pub-dir t))
    (denote-publish-to-md nil file pub-dir)))

(provide 'denote-publish)
;;; denote-publish.el ends here

;; # Notes
;; ## Do not use `org-export-get-category'
;; [tag: do_not_use_org-export-get-category]
;;
;; We do not want the fallback behaviour of `org-export-get-category',
;; which is to return the file-name of the file as the category. For
;; us, this field only makes sense when it has been explicitly
;; defined.
