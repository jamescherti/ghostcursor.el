;;; ghostcursor.el --- Restore the cursor's visual column after saving in Emacs -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Ghostcursor is an Emacs package that preserves the cursor's visual column position after saving a buffer. Save hooks such as delete-trailing-whitespace and eglot-format-buffer can remove trailing whitespace or reformat text, causing the cursor to shift unexpectedly.

;; Author: Ghostcursor is an Emacs package that preserves the cursor's visual column position after saving a buffer. Save hooks such as delete-trailing-whitespace and eglot-format-buffer can remove trailing whitespace or reformat text, causing the cursor to shift unexpectedly. <https://www.jamescherti.com/contact/>
;; Version: 0.9.9
;; URL: https://github.com/jamescherti/ghostcursor.el
;; Keywords: convenience
;; Package-Requires: ((emacs "24.1"))
;; SPDX-License-Identifier: GPL-3.0-or-later

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;; Restore the cursor's visual column after saving in Emacs.

;;; Code:

(defgroup ghostcursor nil
  "Restore the cursor's visual column after saving in Emacs"
  :group 'ghostcursor
  :prefix "ghostcursor-"
  :link '(url-link
          :tag "Github"
          "https://github.com/jamescherti/ghostcursor.el"))

(defcustom ghostcursor-verbose nil
  "Enable displaying verbose messages."
  :type 'boolean
  :group 'ghostcursor)

(defun ghostcursor--message (&rest args)
  "Display a message with the same ARGS arguments as `message'."
  (apply #'message (concat "[ghostcursor] " (car args)) (cdr args)))

(defmacro ghostcursor--verbose-message (&rest args)
  "Display a verbose message with the same ARGS arguments as `message'."
  (declare (indent 0) (debug t))
  `(progn
     (when ghostcursor-verbose
       (ghostcursor--message
        (concat ,(car args)) ,@(cdr args)))))

;;;###autoload
(define-minor-mode ghostcursor-mode
  "Toggle `ghostcursor-mode'."
  :global t
  :lighter " ghostcursor"
  :group 'ghostcursor
  (if ghostcursor-mode
      t
    t))

(provide 'ghostcursor)
;;; ghostcursor.el ends here
