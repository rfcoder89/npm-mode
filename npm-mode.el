;;; npm-mode.el --- minor mode for working with npm projects

;; Version: 0.7.0
;; Author: Richard Flood <rfcoder89@gmail.com>
;; Original Author: Allen Gooch <allen.gooch@gmail.com>
;; Url: https://github.com/mojochao/npm-mode
;; Keywords: convenience, project, javascript, node, npm
;; Package-Requires: ((emacs "24.1"))

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; This package allows you to easily work with npm projects.  It provides
;; a minor mode for convenient interactive use of API with a
;; mode-specific command keymap.
;;
;; | command                         | keymap       | description                         |
;; |---------------------------------|--------------|-------------------------------------|
;; | npm-mode-npm-init               | <kbd>n</kbd> | Initialize new project              |
;; | npm-mode-npm-install            | <kbd>i</kbd> | Install all project dependencies    |
;; | npm-mode-npm-install-save       | <kbd>s</kbd> | Add new project dependency          |
;; | npm-mode-npm-install-save-dev   | <kbd>S</kbd> | Add new project dev dependency      |
;; | npm-mode-npm-uninstall-save     | <kbd>u</kbd> | Remove project dependency           |
;; | npm-mode-npm-uninstall-save-dev | <kbd>U</kbd> | Remove project dependency           |
;; | npm-mode-npm-clean              | <kbd>c</kbd> | Remove node_modules directory       |
;; | npm-mode-npm-list               | <kbd>l</kbd> | List installed project dependencies |
;; | npm-mode-npm-run                | <kbd>r</kbd> | Run project script                  |
;; | npm-mode-visit-project-file     | <kbd>v</kbd> | Visit project package.json file     |
;; | npm-mode-visit-project-dir      | <kbd>d</kbd> | Visit project directory             |
;; |                                 | <kbd>?</kbd> | Display keymap commands             |

;;; Credit:

;; This package began as a fork of the emacsnpm package, and its
;; repository history has been preserved.  Many thanks to Alex
;; for his contribution.
;; https://github.com/AlexChesters/emacs-npm repo.

;;; Code:

(require 'json)

(defvar npm-mode--project-file-name "package.json"
  "The name of npm project files.")

(defvar npm-mode--modeline-name " npm"
  "Name of npm mode modeline name.")

(defun npm-mode--ensure-npm-module ()
  "Asserts that you're currently inside an npm module"
  (npm-mode--project-file))

(defun npm-mode--project-file ()
  "Return path to the project file, or nil.
If project file exists in the current working directory, or a
parent directory recursively, return its path.  Otherwise, return
nil."
  (let ((dir (locate-dominating-file default-directory npm-mode--project-file-name)))
    (unless dir
      (error (concat "Error: cannot find " npm-mode--project-file-name)))
    (concat dir npm-mode--project-file-name)))

(defun npm-mode--get-project-property (prop)
  "Get the given PROP from the current project file."
  (let* ((project-file (npm-mode--project-file))
         (json-object-type 'hash-table)
         (json-contents (shell-command-to-string (concat "cat " project-file)))
         (json-hash (json-read-from-string json-contents))
         (commands (list)))
    (maphash (lambda (key value) (setq commands (append commands (list (list key (format "%s %s" "npm" key)))))) (gethash prop json-hash))
    commands))

(defun npm-mode--get-project-scripts ()
  "Get a list of project scripts."
  (npm-mode--get-project-property "scripts"))

(defun npm-mode--get-project-dependencies ()
  "Get a list of project dependencies."
  (npm-mode--get-project-property "dependencies"))

(defun npm-mode--get-project-dev-dependencies ()
  "Get a list of project dev dependencies."
  (npm-mode--get-project-property "devDependencies"))

(defun npm-mode--exec-process (cmd)
  "Execute a process running CMD."
  (message (concat "Running " cmd))
  (compile cmd))

(defun npm-mode-npm-init ()
  "Run the npm init command."
  (interactive)
  (if (not (locate-dominating-file default-directory npm-mode--project-file-name))
      (npm-mode--exec-process "npm init -y")
    (message "Npm module already initialised")))

(defun npm-mode-npm-install ()
  "Run the 'npm install' command."
  (interactive)
  (npm-mode--ensure-npm-module)
  (npm-mode--exec-process "npm install"))

(defun npm-mode--npm-command (input cmd)
  (when (npm-mode--ensure-npm-module)
    (npm-mode--exec-process
     (format
      cmd
      (funcall input)))))

(defun npm-mode-npm-install-save ()
  "Run the 'npm install --save' command."
  (interactive)
  (npm-mode--npm-command
   (lambda () (read-from-minibuffer "Enter package name: ")) "npm install %s --save"))

(defun npm-mode-npm-install-save-dev ()
  "Run the 'npm install --save' command."
  (interactive)
  (npm-mode--npm-command
   (lambda () (read-from-minibuffer "Enter package name [dev]: "))
   "npm install %s --save-dev"))

(defun npm-mode-npm-uninstall-save ()
  "Run the 'npm uninstall --save' command."
  (interactive)
  (npm-mode--npm-command
   (lambda () (completing-read "Uninstall dependency: " (npm-mode--get-project-dependencies)))
   "npm uninstall %s --save"))

(defun npm-mode-npm-uninstall-save-dev ()
  "Run the 'npm uninstall --save-dev' command."
  (interactive)
  (npm-mode--npm-command
   (lambda () (completing-read "Uninstall dependency [dev]: " (npm-mode--get-project-dev-dependencies)))
   "npm uninstall %s --save-dev"))

(defun npm-mode-npm-clean ()
  "Run the 'npm list' command."
  (interactive)
  (let ((dir (concat (file-name-directory (npm-mode--ensure-npm-module)) "node_modules")))
    (if (file-directory-p dir)
      (when (yes-or-no-p (format "Are you sure you wish to delete %s" dir))
        (npm-mode--exec-process (format "rm -rf %s" dir)))
      (message (format "%s has already been cleaned" dir)))))

(defun npm-mode-npm-list ()
  "Run the 'npm list' command."
  (interactive)
  (npm-mode--ensure-npm-module)
  (npm-mode--exec-process "npm list --depth=0"))

(defun npm-mode-npm-run ()
  "Run the 'npm run' command on a project script."
  (interactive)
  (npm-mode--npm-command
   (lambda () (completing-read "Run script: " (npm-mode--get-project-scripts)))
   "npm run %s"))

(defun npm-mode-visit-project-file ()
  "Visit the project file."
  (interactive)
  (npm-mode--ensure-npm-module)
  (find-file (npm-mode--project-file)))

(defun npm-mode-visit-project-dir ()
  "Visit the project file."
  (interactive)
  (npm-mode--ensure-npm-module)
  (dired (file-name-directory (npm-mode--project-file))))

(defgroup npm-mode nil
  "Customization group for npm-mode."
  :group 'convenience)

(defcustom npm-mode-command-prefix "C-c n"
  "Prefix for npm-mode."
  :group 'npm-mode)

(defvar npm-mode-command-keymap
  (let ((map (make-sparse-keymap)))
    (define-key map "n" 'npm-mode-npm-init)
    (define-key map "i" 'npm-mode-npm-install)
    (define-key map "s" 'npm-mode-npm-install-save)
    (define-key map "S" 'npm-mode-npm-install-save-dev)
    (define-key map "u" 'npm-mode-npm-uninstall-save)
    (define-key map "U" 'npm-mode-npm-uninstall-save-dev)
    (define-key map "c" 'npm-mode-npm-clean)    
    (define-key map "l" 'npm-mode-npm-list)
    (define-key map "r" 'npm-mode-npm-run)
    (define-key map "v" 'npm-mode-visit-project-file)
    (define-key map "d" 'npm-mode-visit-project-dir)
    map)
  "Keymap for npm-mode commands.")

(defvar npm-mode-keymap
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd npm-mode-command-prefix) npm-mode-command-keymap)
    map)
  "Keymap for `npm-mode'.")

;;;###autoload
(define-minor-mode npm-mode
  "Minor mode for working with npm projects."
  nil
  npm-mode--modeline-name
  npm-mode-keymap
  :group 'npm-mode)

;;;###autoload
(define-globalized-minor-mode npm-global-mode
  npm-mode
  npm-mode)

(provide 'npm-mode)
;;; npm-mode.el ends here
