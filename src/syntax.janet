(import ./core)

# These shouldn't go  in ./core.janet because then any code like
# `(section :name)` in ./core.janet breaks because macro bindings
# don't obey lexical shadowing.

(defmacro section [name & body]
  ~(,core/section* ,name (fn [] ,;body)))

(defmacro before [& body]
  ~(,core/before* (fn [] ,;body)))

(defmacro before-each [& body]
  ~(,core/before-each* (fn [] ,;body)))

(defmacro after [& body]
  ~(,core/after* (fn [] ,;body)))

(defmacro after-each [& body]
  ~(,core/after-each* (fn [] ,;body)))

(defmacro test [name & body]
  ~(,core/test* ,name (fn [] ,;body)))
