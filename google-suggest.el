;;; google-suggest.el --- Get google suggestions   -*- lexical-binding: t -*-

;; copypasta
;; credit https://www.reddit.com/user/kcin
;; google and stackexchange integration
;; https://www.reddit.com/r/emacs/comments/e8cm8x/get_stackoverflow_answers_with_completion_without/

(require 'json)
(require 'url)
(require 'thingatpt)

(defun google-suggest-get-completions (query callback)
  "Ask google for suggestions of QUERY and pass json result to CALLBACK."
  (url-retrieve
   (format "http://suggestqueries.google.com/complete/search?client=chrome&q=%s"
           query)
   callback))

(defvar google-suggest-bufname "*google-suggestions*")

(defvar google-suggest-current-buffer nil)

(defvar google-suggest-input nil)

(defvar google-suggest-keymap
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map minibuffer-local-map)
    (define-key map (kbd "C-k") 'google-suggest-prev)
    (define-key map (kbd "C-p") 'google-suggest-prev)
    (define-key map (kbd "C-j") 'google-suggest-next)
    (define-key map (kbd "C-n") 'google-suggest-next)
    (define-key map (kbd "M-n") 'google-suggest-thing-at-point-or-region)
    (define-key map (kbd "<RET>") 'exit-minibuffer)
    map)
  "Kemap to interact with suggestion buffer.")

;;;###autoload
(defun google-suggest ()
  "Get google suggestion while typing.
C-j/C-n for next and C-k/C-p for previous suggestion."
  (interactive)
  (setq google-suggest-current-buffer (current-buffer))
  (let ((wincfg (current-window-configuration)))
    (pop-to-buffer google-suggest-bufname '((display-buffer-at-bottom)
                                            (window-height . 15)))
    (erase-buffer)
    (setq cursor-type nil)
    (add-hook 'post-command-hook 'google-suggest-post-command)
    (setq google-suggest-input nil)
    (if (unwind-protect
            (progn
              (read-from-minibuffer "search for: " nil google-suggest-keymap)
              (and google-suggest-input
                   (not (equal google-suggest-input ""))))
          (remove-hook 'post-command-hook 'google-suggest-post-command)
          (set-window-configuration wincfg))
        (message google-suggest-input))))

(defun google-suggest-post-command ()
  (if (and (not (equal google-suggest-input (minibuffer-contents)))
           (sit-for 0.3))
      (if (equal (minibuffer-contents) "")
          (with-current-buffer (get-buffer google-suggest-bufname)
            (erase-buffer))
        (let ((input (minibuffer-contents)))
          (google-suggest-get-completions
           input
           (lambda (status &rest args)
             (unless status
               (search-forward "\n\n")
               (let ((suggestions (append (aref (json-read) 1) nil)))
                 (with-current-buffer (get-buffer google-suggest-bufname)
                   (erase-buffer)
                   (insert input "\n")
                   (dolist (suggestion suggestions)
                     (insert suggestion "\n"))
                   (goto-char (point-min))
                   (google-suggest-highlight-line)
                   (setq google-suggest-input input))))))))))

(defun google-suggest-highlight-line ()
  (put-text-property (line-beginning-position)
                     (1+ (line-end-position))
                     'face
                     'highlight))

(defun google-suggest-clear-highlight ()
  (put-text-property (line-beginning-position)
                     (1+ (line-end-position))
                     'face
                     'nil))

(defun google-suggest-next ()
  "Select previous suggestion."
  (interactive)
  (with-current-buffer (get-buffer google-suggest-bufname)
    (unless (or (eobp)
                (save-excursion
                  (forward-line 1)
                  (eobp)))
      (google-suggest-clear-highlight)
      (forward-line 1)
      (google-suggest-item-selected))))

(defun google-suggest-prev ()
  "Select next suggestion."
  (interactive)
  (with-current-buffer (get-buffer google-suggest-bufname)
    (unless (bobp)
      (google-suggest-clear-highlight)
      (forward-line -1)
      (google-suggest-item-selected))))

(defun google-suggest-item-selected ()
  (let ((item (with-current-buffer (get-buffer google-suggest-bufname)
                (google-suggest-highlight-line)
                (buffer-substring-no-properties (line-beginning-position)
                                                (line-end-position)))))
    (select-window (minibuffer-window))
    (delete-minibuffer-contents)
    (insert item)
    (setq google-suggest-input item)))

(defun google-suggest-thing-at-point-or-region ()
  "Grab thing at point or active region and insert to prompt."
  (interactive)
  (with-current-buffer google-suggest-current-buffer
    (when-let (item (if (use-region-p)
                        (buffer-substring-no-properties (region-beginning) (region-end))
                      (thing-at-point 'symbol t)))
      (select-window (minibuffer-window))
      (delete-minibuffer-contents)
      (insert item)
      (setq google-suggest-input item))))

(provide 'google-suggest)
;;; google-suggest.el ends here
