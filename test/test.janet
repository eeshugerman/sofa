(import ../src/sofa :as t)

(def things-ran @[])

(defn assert-things-ran [things]
  (assert (deep= things-ran (array (splice things)))))

################################################################################
# basic group
################################################################################
(t/reset)
(array/clear things-ran)

(t/group
  "test/lib.janet works"
  (fn []
    (t/before (fn [] (array/push things-ran 'before)))
    (t/before-each (fn [] (array/push things-ran 'before-each)))
    (t/test
      "this should pass"
      (fn []
        (array/push things-ran 'passing-test)
        (assert true)))
    (t/test
      "this should fail"
      (fn []
        (array/push things-ran 'failing-test)
        (assert false)))
    (t/after (fn [] (array/push things-ran 'after)))
    (t/after-each (fn [] (array/push things-ran 'after-each)))))

(def {:results results :counts counts } (t/run-tests :exit-on-failure false))

(assert-things-ran
 '(before
   before-each passing-test after-each
   before-each failing-test after-each
   after))
(assert (= (counts :failed) 1))
(assert (= (counts :passed) 1))

################################################################################
# implicit top-level group
################################################################################
(t/reset)
(array/clear things-ran)

(t/before (fn [] (array/push things-ran 'before)))
(t/before-each (fn [] (array/push things-ran 'before-each)))
(t/test
  "this should pass"
  (fn []
    (array/push things-ran 'passing-test)
    (assert true)))
(t/test
  "this should fail"
  (fn []
    (array/push things-ran 'failing-test)
    (assert false)))
(t/after (fn [] (array/push things-ran 'after)))
(t/after-each (fn [] (array/push things-ran 'after-each)))

(t/run-tests :exit-on-failure false)

(assert-things-ran
 '(before
   before-each passing-test after-each
   before-each failing-test after-each
   after))
(assert (= (counts :failed) 1))
(assert (= (counts :passed) 1))