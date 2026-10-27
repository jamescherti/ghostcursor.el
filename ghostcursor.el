;;; ghostcursor.el --- Restore cursor column after save hooks -*- lexical-binding: t; -*-

;; Author: James Cherti
;; URL: https://github.com/jamescherti/jc-dev
;; Package-Requires: ((emacs "24.3"))
;; Keywords: convenience
;; Version: 0.0.9
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; The ghostcursor package provides a mode that records the exact cursor
;; column position immediately before a buffer is saved and restores it
;; afterward.
;;
;; The problem: Save hooks (such as `delete-trailing-whitespace' or
;; `eglot-format-buffer', apheleia) often truncate trailing spaces, which can
;; force the cursor back to the last non-whitespace character and disrupt the
;; editing workflow. This package ensures the cursor remains exactly where it
;; was before the save operation.
;;
;; This package doesn't modify your buffer on save. When restoring the cursor
;; requires placing it beyond the current physical end of a line, inserting real
;; whitespace would pollute the file with unwanted trailing spaces. To prevent
;; this, the ghostcursor dynamically applies a virtual overlay, which
;; visually renders the cursor at the correct column without modifying the
;; actual buffer text.
;;
;; The virtual overlay is ephemeral. Once the user moves the cursor or triggers
;; another command, the overlay is automatically cleared via `pre-command-hook'.
;; If the user inserts a character while at the virtual column, the missing
;; whitespace is materialized before the character is inserted.
;;
;; Features:
;; - Maintains the exact cursor column on save without modifying the underlying
;;   buffer text.
;; - Uses virtual overlay strings to render the cursor position.
;; - Materializes whitespace only when the user types at the restored column.
;; - Overlays automatically clear on cursor movement or other commands.
;; - Operates correctly across base buffers and indirect buffers.
;;
;; Usage:
;; Enable locally via `ghostcursor-local-mode', or globally via
;; `ghostcursor-global-mode'.

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

(defun ghostcursor--clear-virtual-state ()
  "Clean up virtual overlay and hooks without modifying the buffer."
  ;; Check if the variable holds a valid overlay descriptor.
  (when (overlayp ghostcursor--virtual-overlay)
    ;; Remove the overlay from the buffer display list to stop rendering it.
    (delete-overlay ghostcursor--virtual-overlay)
    (setq ghostcursor--virtual-overlay nil))
  (setq ghostcursor--saved-column nil)
  (remove-hook 'pre-command-hook #'ghostcursor--pre-command-handler t))

(defun ghostcursor--pre-command-handler ()
  "Materialize virtual spaces on self-insert or clear the virtual overlay."
  (unwind-protect
      (when (and (not buffer-read-only)
                 (overlayp ghostcursor--virtual-overlay)
                 ghostcursor--saved-column
                 (memq this-command '(self-insert-command
                                      org-self-insert-command
                                      quoted-insert)))
        (let ((ov-start (overlay-start ghostcursor--virtual-overlay)))
          (when (and ov-start (eq (point) ov-start) (eolp))
            (move-to-column ghostcursor--saved-column t))))
    ;; Clean up overlay and unregister the hook.
    (ghostcursor--clear-virtual-state)))

(defun ghostcursor--before-save-hook ()
  "Save the current visual column position before saving."
  (let ((win-buf (window-buffer (selected-window))))
    (when (eq (current-buffer) (or (buffer-base-buffer win-buf)
                                   win-buf))
      ;; Operate in `win-buf' so `point', `current-column', and buffer-local
      ;; variables reflect the indirect or base buffer shown in the window.
      (with-current-buffer win-buf
        ;; If a virtual overlay is already active from a previous save, preserve
        ;; `ghostcursor--saved-column' before clearing state.
        (let ((col ghostcursor--saved-column))
          (ghostcursor--clear-virtual-state)
          (setq ghostcursor--saved-column (or col (current-column))))))))

(defun ghostcursor--after-save-hook ()
  "Restore the cursor to the previously saved column using a virtual overlay."
  (let ((win-buf (window-buffer (selected-window))))
    (when (eq (current-buffer)
              (or (buffer-base-buffer win-buf) win-buf))
      (with-current-buffer win-buf
        (when ghostcursor--saved-column
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
  "Turn on `ghostcursor-local-mode' for the current buffer."
  (unless (minibufferp)
    (ghostcursor-local-mode 1)))

;;;###autoload
(define-minor-mode ghostcursor-local-mode
  "Minor mode to restore the cursor column after saving."
  :lighter " RCol"
  :group 'ghostcursor
  (if ghostcursor-local-mode
      (progn
        (add-hook 'before-save-hook #'ghostcursor--before-save-hook
                  ghostcursor-before-save-hook-depth t)
        (add-hook 'after-save-hook #'ghostcursor--after-save-hook
                  ghostcursor-after-save-hook-depth t))
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
