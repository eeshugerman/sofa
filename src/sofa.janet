(def divider-heavy "================================================================================")
(def divider-light "--------------------------------------------------------------------------------")

(defn- section/new [description]
  @{:type 'section
    :description description
    :children @[]
    :before nil
    :before-each nil
    :after nil
    :after-each nil})

# TODO: default to filename (argv[1])
(def top-section-name "<top>")

(var top-section (section/new top-section-name))

# All this does is make (dyn *section*) not throw "unknown symbol *section*".
# We still can't use *section* as a global -- we'll need a regular binding
# (`top-section`) for that.
(defdyn *section*)

(defn reset []
  (set top-section (section/new top-section-name)))

(defn- get-parent-section []
  (or (dyn *section*) top-section))

(defn section [description thunk]
  (def parent-section (get-parent-section))
  (def this-section
    (with-dyns [*section* (section/new description)]
      (thunk)
      (dyn *section*)))
  (array/push (parent-section :children) this-section))

(defn before [thunk]
  # TODO: throw if already set
  (set ((get-parent-section) :before) thunk))

(defn before-each [thunk]
  (set ((get-parent-section) :before-each) thunk))

(defn after [thunk]
  (set ((get-parent-section) :after) thunk))

(defn after-each [thunk]
  (set ((get-parent-section) :after-each) thunk))

(defn test [description thunk]
  (array/push
    ((get-parent-section) :children)
    {:type 'test
     :description description
     :thunk thunk}))


(defn execute-section [section]
  # TODO: catch errors in hooks?
  # TODO: print output indentation
  (print (section :description))
  (when-let [before (section :before)]
    (before))
  (def children-results
    (map (fn [child]
           (when-let [before-each (section :before-each)]
             (before-each))
           (def child-result
             (match child
               {:type 'test :thunk thunk :description desc}
               (try
                 (do
                   (thunk)
                   (printf "* %s ✅" desc)
                   {:type 'test :description desc :passed true})
                 ([err]
                   (printf "* %s ❌" desc)
                   {:type 'test :description desc :passed false :error err}))
               {:type 'section}
               (execute-section child)))
           (when-let [after-each (section :after-each)]
             (after-each))
           child-result)
         (section :children)))
  (when-let [after (section :after)]
    (after))
  {:type 'section :description (section :description) :children children-results})


(defn- get-spaces [n]
  (->> (range n)
       (map (fn [x] " "))
       (string/join)))


(defn- filter-failures [results]
  (def filtered-children
    (reduce
      (fn [acc child]
        (match child
          {:type 'test :passed true} acc
          {:type 'test :passed false} (array/push acc child)
          {:type 'section} (array/push acc (filter-failures child))))
      (array)
      (results :children)))
  (merge results {:children filtered-children}))


(defn- print-failures [results depth]
  (def indent (get-spaces (* 2 depth)))
  (match results
    {:type 'section :description desc :children children}
    (do
      (print indent desc)
      (each child children
        (print-failures child (+ 1 depth))))
    {:type 'test :description desc :error err}
    (do
      (print indent desc)
      (print err)
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
  # TODO: elide implicit top section
  (print "FAILURES:")
  (print divider-light)
  (print-failures (filter-failures results) 0)
  (print divider-heavy)

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
