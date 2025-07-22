;;; wrapsher-mode.el --- Major mode for editing Wrapsher code -*- lexical-binding: t; -*-

(defvar wrapsher-mode-hook nil)

(defvar wrapsher-keywords
  '("if" "else" "use" "module" "meta" "type"
    "fun" "return" "while" "break" "continue" "shell"
    ))

(defvar wrapsher-types
  '("int" "bool" "string" "reflist" "ref" "list" "map" "pair" "error"))

(defvar wrapsher-font-lock-defaults
  `(
    ("\\<\\(TODO\\|FIXME\\|NOTE\\):" 1 font-lock-warning-face t)
    (, (regexp-opt wrapsher-keywords 'words) . font-lock-keyword-face)
    (, (regexp-opt wrapsher-types 'words) . font-lock-type-face)
    ("\\<\\([A-Za-z_/][A-Za-z0-9_/]*\\)(" 1 font-lock-function-name-face)
    )
  )

(defvar wrapsher-mode-syntax-table
  (let ((st (make-syntax-table)))
    (modify-syntax-entry ?_ "w" st)
    (modify-syntax-entry ?/ "w" st)
    (modify-syntax-entry ?# "<" st)
    (modify-syntax-entry ?\n ">" st)
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
  "Apply syntax properties for triple-quoted strings."
  (goto-char start)
  (funcall
   (syntax-propertize-rules
    ;; Match opening triple quote
    ("\\('''\\)"
     (1 (prog1 "|"
          (put-text-property (match-beginning 1)
                             (match-end 1)
                             'wrapsher-triple-quote 'start))))
    ;; Match closing triple quote
    ("\\('''\\)"
     (1 (when (get-text-property (match-beginning 1) 'wrapsher-triple-quote)
          "\""))))
   start end))


(defun wrapsher-indent-line ()
  "Indent current line for Wrapsher."
  (interactive)
  (let ((indent-level 2))  ;; Change to 4 if you prefer
    (indent-line-to (* indent-level (car (syntax-ppss))))))

;;;###autoload
(define-derived-mode wrapsher-mode prog-mode "Wrapsher"
  "Major mode for editing Wrapsher language code."
  :syntax-table wrapsher-mode-syntax-table
  (setq font-lock-defaults `(,wrapsher-font-lock-defaults))
  (setq-local syntax-propertize-function #'wrapsher-syntax-propertize)
  (setq-local indent-line-function #'wrapsher-indent-line))


;;;###autoload
(add-to-list 'auto-mode-alist '("\\.wsh\\'" . wrapsher-mode))

(provide 'wrapsher-mode)
;;; wrapsher-mode.el ends here
