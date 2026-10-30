;;; ghostcursor.el --- Restore cursor column after save hooks -*- lexical-binding: t; -*-

;; Copyright (C) 2026 James Cherti | https://www.jamescherti.com/contact/

;; Author: James Cherti <https://www.jamescherti.com/contact/>
;; URL: https://github.com/jamescherti/jc-dev
;; Package-Requires: ((emacs "24.3"))
;; Keywords: convenience
;; Version: 0.0.9
;; SPDX-License-Identifier: GPL-3.0-or-later

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;; Copyright (C) 2024-2026 James Cherti | https://www.jamescherti.com/contact/

;;; Commentary:
;; The ghostcursor package provides a mode that records the exact cursor column
;; position immediately before a buffer is saved and restores it afterward.
;;
;; The benefit of restoring the cursor column: Save hooks (such as
;; `delete-trailing-whitespace', `eglot-format-buffer', or the apheleia package)
;; often truncate trailing spaces. This can force the cursor back to the last
;; non-whitespace character.
;;
;; Does this package add real spaces to restore the column?
;; --------------------------------------------------------
;; The ghostcursor package visually renders the cursor at the correct column
;; without modifying the actual buffer text.
;;
;; Features:
;; ---------
;; - Maintains the exact cursor column on save without modifying the
;;   underlying buffer text.
;; - Uses virtual overlay strings to render the cursor position.
;; - Materializes whitespace only when the user types at the restored column.
;; - Overlays automatically clear on cursor movement or other commands.
;; - Operates correctly across base buffers and indirect buffers.

;;; Code:

(defgroup ghostcursor nil
  "Restore the cursor column after save hooks."
  :group 'convenience
  :prefix "ghostcursor-")

(defcustom ghostcursor-before-save-hook-depth -99
  "Depth for `ghostcursor--before-save-hook' in `before-save-hook'.
A negative depth ensures it runs early to save the column before other
modifications occur."
  :type 'integer
  :group 'ghostcursor)

(defcustom ghostcursor-after-save-hook-depth 99
  "Depth for `ghostcursor--after-save-hook' in `after-save-hook'.
A positive depth ensures it runs late to restore the column after all other
post-save processing is complete."
  :type 'integer
  :group 'ghostcursor)

(defvar-local ghostcursor--saved-column nil
  "Internal variable to store the column position before saving.")

(defvar-local ghostcursor--virtual-overlay nil
  "Overlay used to display virtual whitespace.")

(defun ghostcursor--file-visiting-buffer-p ()
  "Return non-nil if the current buffer or its base visits a file."
  (buffer-file-name (or (buffer-base-buffer)
                        (current-buffer))))

(defcustom ghostcursor-buffer-predicate
  #'ghostcursor--file-visiting-buffer-p
  "Function determining whether Ghostcursor should be enabled in a buffer.
The function is called without arguments in the current buffer.
A non-nil return value allows automatic activation."
  :type 'function
  :group 'ghostcursor)

(defun ghostcursor--clear-virtual-state ()
  "Clean up virtual overlay and hooks without modifying the buffer."
  ;; Check if the variable holds a valid overlay descriptor.
  (when (overlayp ghostcursor--virtual-overlay)
    ;; Remove the overlay from the buffer display list to stop rendering it.
    (when (eq (overlay-buffer ghostcursor--virtual-overlay) (current-buffer))
      (delete-overlay ghostcursor--virtual-overlay))
    (setq ghostcursor--virtual-overlay nil))
  (setq ghostcursor--saved-column nil)
  (remove-hook 'pre-command-hook #'ghostcursor--pre-command-handler t))

(defun ghostcursor--pre-command-handler ()
  "Materialize virtual spaces on self-insert or clear the virtual overlay."
  (if (bound-and-true-p ghostcursor-local-mode)
      (unwind-protect
          (when (and (not buffer-read-only)
                     (overlayp ghostcursor--virtual-overlay)
                     (eq (overlay-buffer ghostcursor--virtual-overlay)
                         (current-buffer))
                     ghostcursor--saved-column
                     (memq this-command '(self-insert-command
                                          org-self-insert-command
                                          quoted-insert)))
            (let ((ov-start (overlay-start ghostcursor--virtual-overlay)))
              (when (and ov-start
                         (eq (point) ov-start)
                         (eolp))
                (move-to-column ghostcursor--saved-column t))))
        ;; Clean up overlay and unregister the hook.
        (ghostcursor--clear-virtual-state))
    (ghostcursor--clear-virtual-state)))

(defun ghostcursor--before-save-hook ()
  "Save the current visual column position before saving."
  (let ((win-buf (window-buffer)))
    (when (and win-buf
               (eq (current-buffer) (or (buffer-base-buffer win-buf)
                                        win-buf)))
      ;; Operate in `win-buf' so `point', `current-column', and buffer-local
      ;; variables reflect the indirect or base buffer shown in the window.
      (with-current-buffer win-buf
        (when (bound-and-true-p ghostcursor-local-mode)
          ;; If a virtual overlay is already active from a previous save,
          ;; preserve `ghostcursor--saved-column' before clearing state.
          (let ((col (and (overlayp ghostcursor--virtual-overlay)
                          (eq (overlay-buffer ghostcursor--virtual-overlay)
                              (current-buffer))
                          ghostcursor--saved-column)))
            (ghostcursor--clear-virtual-state)
            (setq ghostcursor--saved-column (or col (current-column)))))))))

(defun ghostcursor--after-save-hook ()
  "Restore the cursor to the previously saved column using a virtual overlay."
  (let ((win-buf (window-buffer)))
    (when (and win-buf
               (eq (current-buffer)
                   (or (buffer-base-buffer win-buf) win-buf)))
      (with-current-buffer win-buf
        (when (and (bound-and-true-p ghostcursor-local-mode)
                   ghostcursor--saved-column)
          ;; nil for FORCE guarantees real spaces are NEVER inserted
          (move-to-column ghostcursor--saved-column)
          (let ((missing-spaces (- ghostcursor--saved-column
                                   (current-column))))
            (if (> missing-spaces 0)
                ;; Build a virtual string containing padding spaces plus one
                ;; space for cursor positioning.
                (let ((display-spaces (make-string (1+ missing-spaces) ?\s))
                      ;; Instantiate a zero-width overlay at point in the
                      ;; current buffer. Both front-advance and rear-advance are
                      ;; nil so insertions at point do not shift overlay-start.
                      (ov (make-overlay (point) (point))))
                  ;; Attach the 'cursor text property to the final character of
                  ;; the virtual string. This tells the display engine to render
                  ;; the cursor glyph at that visual column.
                  (put-text-property missing-spaces (1+ missing-spaces)
                                     'cursor t display-spaces)
                  ;; Restrict the overlay display to the currently active
                  ;; window.
                  (overlay-put ov 'window (selected-window))
                  ;; Set the overlay 'after-string property to display the
                  ;; virtual spaces visually without modifying the underlying
                  ;; buffer text.
                  (overlay-put ov 'after-string display-spaces)
                  ;; Store the overlay reference in the buffer-local variable
                  ;; for tracking.
                  (setq ghostcursor--virtual-overlay ov)
                  ;; Register buffer-local pre-command-hook to tear down the
                  ;; overlay or materialize spaces on user action.
                  (add-hook 'pre-command-hook
                            #'ghostcursor--pre-command-handler nil t))
              (setq ghostcursor--saved-column nil))))))))

(defun ghostcursor--enable ()
  "Enable `ghostcursor-local-mode' in eligible buffers."
  (when (and ghostcursor-buffer-predicate
             (funcall ghostcursor-buffer-predicate))
    (ghostcursor-local-mode 1)))

;;;###autoload
(define-minor-mode ghostcursor-local-mode
  "Minor mode to restore the cursor column after saving."
  :lighter nil
  :group 'ghostcursor
  (if ghostcursor-local-mode
      (progn
        (add-hook 'before-save-hook #'ghostcursor--before-save-hook
                  (if (>= emacs-major-version 27)
                      ghostcursor-before-save-hook-depth
                    nil)
                  t)
        (add-hook 'after-save-hook #'ghostcursor--after-save-hook
                  (if (>= emacs-major-version 27)
                      ghostcursor-after-save-hook-depth
                    t)
                  t))
    ;; Delete overlay and detach pre-command listener when the mode is
    ;; disabled.
    (ghostcursor--clear-virtual-state)
    (remove-hook 'before-save-hook #'ghostcursor--before-save-hook t)
    (remove-hook 'after-save-hook #'ghostcursor--after-save-hook t)))

;;;###autoload
(define-globalized-minor-mode ghostcursor-global-mode
  ghostcursor-local-mode
  ghostcursor--enable
  :group 'ghostcursor)

(provide 'ghostcursor)

;;; ghostcursor.el ends here
