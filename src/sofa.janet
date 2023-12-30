(def divider-heavy "================================================================================")
(def divider-light "--------------------------------------------------------------------------------")

(defn- section/new [name]
  @{:type 'section
    :name name
    :children @[]
    :before nil
    :before-each nil
    :after nil
    :after-each nil})

# TODO: default to filename (argv[1]) or something?
(def- top-section-name "<top>")

(var- top-section (section/new top-section-name))

(defn reset []
  (set top-section (section/new top-section-name)))

# All this does is make (dyn *section*) not throw "unknown symbol *section*".
# We still can't use *section* as a global -- we'll need a regular binding
# (`top-section`) for that.
(defdyn *section*)

(defn- get-parent-section []
  (or (dyn *section*) top-section))

(defn section [name thunk]
  (def parent-section (get-parent-section))
  (def this-section
    (with-dyns [*section* (section/new name)]
      (thunk)
      (dyn *section*)))
  (array/push (parent-section :children) this-section)
  nil)

(defn before [thunk]
  # TODO: throw if already set
  (set ((get-parent-section) :before) thunk))

(defn before-each [thunk]
  (set ((get-parent-section) :before-each) thunk))

(defn after [thunk]
  (set ((get-parent-section) :after) thunk))

(defn after-each [thunk]
  (set ((get-parent-section) :after-each) thunk))

(defn test [name thunk]
  (array/push
    ((get-parent-section) :children)
    {:type 'test
     :name name
     :thunk thunk})
  nil)


(defn- get-indent [n]
  (->> (range n)
       (map (fn [x] "  "))
       (string/join)))


(defn- execute-test [test depth]
  # We need the fiber, not just the error it may throw, to get the pretty-printed
  # stacktrace later. The "err" value captured with the `try` macro is just the
  # error message. Well, we _could_ grab just the stack here, but then we'd have
  # to render/pretty-print it by hand. Still we _could_ call override (dyn :out)
  # here, but meh might as just pass the fiber around.
  # https://janet-lang.org/docs/fibers/error_handling.html
  # https://janet-lang.org/api/debug.html#debug/stack
  # https://janet-lang.org/api/debug.html#debug/stacktrace
  (let [{:thunk thunk :name name} test
        test-fiber (fiber/new thunk :e)
        result (resume test-fiber)]
    (if (not= (fiber/status test-fiber) :error)
      (do
        (printf "%s%s ✅" (get-indent depth) name)
        {:type 'test :name name :passed true})
      (do
        (printf "%s%s ❌" (get-indent depth) name)
        {:type 'test
         :name name
         :passed false
         :fiber test-fiber
         :error-message result}))))


# TODO: catch errors in hooks? and propogate errors in hooks to results?
# TODO: skip remaining tests in section if hook fails? what does mocha do here?
(defn- execute-section
  [section &keys {:depth depth
                  :inherited-before-each-hooks inherited-before-each-hooks
                  :inherited-after-each-hooks inherited-after-each-hooks}]
  (default depth 0)
  (default inherited-before-each-hooks [])
  (default inherited-after-each-hooks [])

  (print (get-indent depth) (section :name))

  (when-let [before (section :before)]
    (before))

  (def children-results
    (let [before-each-hooks
          (let [own (section :before-each)
                inherited inherited-before-each-hooks]
            (if own [(splice inherited) own] inherited))
          after-each-hooks
          (let [own (section :after-each)
                inherited inherited-after-each-hooks]
            (if own [own (splice inherited)] inherited))]
      (map
        (fn [child]
          (match child
            {:type 'test}
            (do
              (each hook before-each-hooks (hook))
              (def child-result (execute-test child (+ 1 depth)))
              (each hook after-each-hooks (hook))
              child-result)
            {:type 'section}
            (execute-section
              child
              :depth (+ 1 depth)
              :inherited-before-each-hooks before-each-hooks
              :inherited-after-each-hooks after-each-hooks)))
        (section :children))))

  (when-let [after (section :after)]
    (after))

  {:type 'section :name (section :name) :children children-results})


(defn- filter-failures [results]
  (def filtered-children
    (reduce
      (fn [acc child]
        (match child
          {:type 'test :passed true} acc
          {:type 'test :passed false} (array/push acc child)
          {:type 'section} (if-let [filtered-section (filter-failures child)]
                             (array/push acc filtered-section)
                             acc)))
      (array)
      (results :children)))
  (if (empty? filtered-children)
    nil
    (merge results {:children filtered-children})))


(defn- print-failures [results &opt depth]
  (default depth 0)
  (match results
    {:type 'section :name name :children children}
    (do
      (print (get-indent depth) name)
      (each child children
        (print-failures child (+ 1 depth))))
    {:type 'test :name name :fiber fiber :error-message message}
    (do
      (print (get-indent depth) name)
      (print message)
      (debug/stacktrace fiber)
      (print))))


(defn- count-tests [results]
  (reduce
    (fn [acc child]
      (match child
        {:type 'test :passed true} (merge acc {:passed (+ 1 (acc :passed))})
        {:type 'test :passed false} (merge acc {:failed (+ 1 (acc :failed))})
        {:type 'section} (let [counts (count-tests child)]
                           {:passed (+ (acc :passed) (counts :passed))
                            :failed (+ (acc :failed) (counts :failed))})))
    {:passed 0 :failed 0}
    (results :children)))


(defn- report [results]
  (when-let [failures (filter-failures results)]
    (print "FAILURES:")
    (print divider-light)
    (print-failures failures)
    (print divider-heavy))

  (print "SUMMARY:")
  (print divider-light)
  (let [{:passed num-passed :failed num-failed} (count-tests results)
        num-total (+ num-failed num-passed)]
    (printf "Total:    %i" num-total)
    (printf "Passing:  %i" num-passed)
    (printf "Failed:   %i" num-failed))
  (print divider-heavy))


(defn run-tests [&keys {:exit-on-failure exit-on-failure}]
  (default exit-on-failure true)

  (print divider-heavy)
  (print "Running tests...")
  (print divider-light)
  (def results (execute-section top-section))
  (print divider-heavy)

  (report results)

  (let [counts (count-tests results)]
    (when (and (> (counts :failed) 0) exit-on-failure)
      (os/exit 1))
    {:results results :counts counts}))
