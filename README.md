# ghostcursor.el
![Build Status](https://github.com/jamescherti/ghostcursor.el/actions/workflows/melpazoid.yml/badge.svg)
![License](https://img.shields.io/github/license/jamescherti/ghostcursor.el)
![](https://jamescherti.com/misc/made-for-gnu-emacs.svg)

- Author: James Cherti <[https://www.jamescherti.com/](https://www.jamescherti.com/)>
- License: GPL

Restore the cursor's visual column after saving in Emacs.

## Installation

### Emacs: use-package and straight (Emacs version < 30)

To install *ghostcursor* with `straight.el`:

1. If it hasn't already been done, [add the straight.el bootstrap code](https://github.com/radian-software/straight.el?tab=readme-ov-file#getting-started) to your init file.
2. Add the following code to the Emacs init file:
```emacs-lisp
(use-package ghostcursor
  :straight (ghostcursor
             :type git
             :host github
             :repo "jamescherti/ghostcursor.el"))
```

### Alternative installation: use-package and :vc (Built-in feature in Emacs version >= 30)

To install *ghostcursor* with `use-package` and `:vc` (Emacs >= 30):

``` emacs-lisp
(use-package ghostcursor
  :vc (:url "https://github.com/jamescherti/ghostcursor.el"
       :rev :newest))
```

### Alternative installation: Doom Emacs

Here is how to install *ghostcursor* on Doom Emacs:

1. Add to the `~/.doom.d/packages.el` file:
```elisp
(package! ghostcursor
  :recipe
  (:host github :repo "jamescherti/ghostcursor.el"))
```

2. Add to `~/.doom.d/config.el`:
```elisp
(after! ghostcursor
  ;; TODO: setq options
  ;; TODO: Load the mode here
  )
```

3. Run the `doom sync` command:
```
doom sync
```

## Author and License

The *ghostcursor* Emacs package has been written by [James Cherti](https://www.jamescherti.com/) and is distributed under terms of the GNU General Public License version 3, or, at your choice, any later version.

Copyright (C) 2026 James Cherti

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details. You should have received a copy of the GNU General Public License along with this program.

## Links

- [ghostcursor.el @GitHub](https://github.com/jamescherti/ghostcursor.el)
