;;; wrapsher-mode.el --- Major mode for editing Wrapsher code -*- lexical-binding: t; -*-

(defvar wrapsher-mode-hook nil)

(defvar wrapsher-keywords
  '("if" "else" "use" "module" "meta" "type" "struct"
    "fun" "return" "while" "break" "continue" "shell"
    "throw" "try" "catch"
    ))

(defvar wrapsher-types
  '("any" "int" "bool" "string" "reflist" "ref" "list" "map" "pair" "error" "builtin"))

(defvar wrapsher-constants
  '("true" "false"))

(defvar wrapsher-font-lock-defaults
  `(
    ("\\<\\(TODO\\|FIXME\\|NOTE\\):" 1 font-lock-warning-face t)
    (, (regexp-opt wrapsher-keywords 'words) . font-lock-keyword-face)
    (, (regexp-opt wrapsher-types 'words) . font-lock-type-face)
    (, (regexp-opt wrapsher-constants 'words) . font-lock-constant-face)
    ("\\<\\([A-Za-z_/][A-Za-z0-9_/]*\\)(" 1 font-lock-function-name-face)
    )
  )

(defvar wrapsher-mode-syntax-table
  (let ((st (make-syntax-table)))
    (modify-syntax-entry ?_ "w" st)
    (modify-syntax-entry ?/ "w" st)
    (modify-syntax-entry ?# "<" st)
    (modify-syntax-entry ?\n ">" st)
    (modify-syntax-entry ?\' "\"" st)
    (modify-syntax-entry ?\\ "\\" st)
    (modify-syntax-entry ?\( "()" st)
    (modify-syntax-entry ?\) ")(" st)
    (modify-syntax-entry ?\[ "(]" st)
    (modify-syntax-entry ?\] ")[" st)
    (modify-syntax-entry ?\{ "(}" st)
    (modify-syntax-entry ?\} "){" st)
    st)
  "Syntax table for `wrapsher-mode'.")

(defun wrapsher-syntax-propertize (start end)
  (funcall
   (syntax-propertize-rules
    ;; triple-quoted strings are a single string rather than 3
    ("'''"
     (0 (ignore (wrapsher-syntax-stringify)))))
   start end))

;; inspired by triple-quote handling in julia-mode
(defun wrapsher-syntax-stringify ()
  "Put `syntax-table' property correctly on triple-quoted strings and cmds."
  (let* ((ppss (save-excursion (syntax-ppss (match-beginning 0))))
         (string-open (and (not (nth 4 ppss)) (nth 8 ppss))))
    (cond
     ;; this set of quotes delimit the start of string/cmd
     ((not string-open)
      (put-text-property (match-beginning 0) (1+ (match-beginning 0))
                         'syntax-table (string-to-syntax "|")))
     ;; this set of quotes closes the current string/cmd
     ((and
       ;; check that ''' closes '''
       (eq (char-before) (char-after string-open))
       ;; check that triple quote isn't escaped by odd number of backslashes
       (let ((i 0))
         (while (and (< (point-min) (- (match-beginning 0) i))
                     (eq (char-before (- (match-beginning 0) i)) ?\\))
           (setq i (1+ i)))
         (cl-evenp i)))
      (put-text-property (1- (match-end 0)) (match-end 0)
                         'syntax-table (string-to-syntax "|")))
     ;; Put point after (match-beginning 0) to account for possibility
     ;; of overlapping triple-quotes with first escaped
     ((backward-char 2)))))

(defun wrapsher-indent-line ()
  "Indent current line for Wrapsher."
  (interactive)
  (let ((indent-level 2))
    (indent-line-to (* indent-level (car (syntax-ppss))))))

(define-derived-mode wrapsher-mode prog-mode "Wrapsher"
  "Major mode for editing Wrapsher language code."
  :syntax-table wrapsher-mode-syntax-table
  (setq font-lock-defaults `(,wrapsher-font-lock-defaults))
  (setq-local syntax-propertize-function #'wrapsher-syntax-propertize)
  (setq-local indent-line-function #'wrapsher-indent-line))


(add-to-list 'auto-mode-alist '("\\.wsh\\'" . wrapsher-mode))

(provide 'wrapsher-mode)
;;; wrapsher-mode.el ends here
