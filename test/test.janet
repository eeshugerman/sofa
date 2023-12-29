(import ../src/sofa :as t)

(def things-ran @[])
(defn assert-things-ran [things]
  (assert (deep= things-ran (array (splice things)))))

################################################################################
# simple passing case
################################################################################
(t/reset)
(array/clear things-ran)

(t/test
  "this should pass"
  (fn []
    (array/push things-ran 'passing-test)
    (assert true)))

(let [{:counts counts} (t/run-tests :exit-on-failure false)]
  (assert-things-ran '(passing-test))
  (assert (= (counts :passed) 1)))

################################################################################
# implicit top-level section
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

(let [{:counts counts} (t/run-tests :exit-on-failure false)]
  (assert-things-ran
    '[before
      before-each passing-test after-each
      before-each failing-test after-each
      after])
  (assert (= (counts :failed) 1))
  (assert (= (counts :passed) 1)))

################################################################################
# explicit section
################################################################################
(t/reset)
(array/clear things-ran)

(t/section
  "basic section"
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

(let [{:counts counts} (t/run-tests :exit-on-failure false)]
  (assert-things-ran
    '[before
      before-each passing-test after-each
      before-each failing-test after-each
      after])
  (assert (= (counts :failed) 1))
  (assert (= (counts :passed) 1)))


################################################################################
# multiple sections
################################################################################
(t/reset)
(array/clear things-ran)

(t/section
  "section a"
  (fn []
    (t/before (fn [] (array/push things-ran 'before-a)))
    (t/before-each (fn [] (array/push things-ran 'before-each-a)))
    (t/test
      "this should pass (1/2)"
      (fn []
        (array/push things-ran 'test-a-1)
        (assert true)))
    (t/test
      "this should pass (1/2)"
      (fn []
        (array/push things-ran 'test-a-2)
        (assert true)))
    (t/after (fn [] (array/push things-ran 'after-a)))
    (t/after-each (fn [] (array/push things-ran 'after-each-a)))))

(t/section
  "section b"
  (fn []
    (t/before (fn [] (array/push things-ran 'before-b)))
    (t/before-each (fn [] (array/push things-ran 'before-each-b)))
    (t/test
      "this should fail (1/2)"
      (fn []
        (array/push things-ran 'test-b-1)
        (assert false)))
    (t/test
      "this should fail (2/2)"
      (fn []
        (array/push things-ran 'test-b-2)
        (assert false)))
    (t/after (fn [] (array/push things-ran 'after-b)))
    (t/after-each (fn [] (array/push things-ran 'after-each-b)))))

(let [{:counts counts} (t/run-tests :exit-on-failure false)]
  (assert-things-ran
    '[before-a
      before-each-a test-a-1 after-each-a
      before-each-a test-a-2 after-each-a
      after-a

      before-b
      before-each-b test-b-1 after-each-b
      before-each-b test-b-2 after-each-b
      after-b])

  (assert (= (counts :failed) 2))
  (assert (= (counts :passed) 2)))


################################################################################
# nested sections (TODO: change behavior to match mocha)
################################################################################
(t/reset)
(array/clear things-ran)

(t/section
  "outer section"
  (fn []
    (t/before (fn [] (array/push things-ran 'outer-before)))
    (t/before-each (fn [] (array/push things-ran 'outer-before-each)))
    (t/after (fn [] (array/push things-ran 'outer-after)))
    (t/after-each (fn [] (array/push things-ran 'outer-after-each)))

    (t/test
     "outer test (fail)"
     (fn []
       (array/push things-ran 'outer-test-1)
       (assert false)))

    (t/section
      "inner section"
      (fn []
        (t/before (fn [] (array/push things-ran 'inner-before)))
        (t/before-each (fn [] (array/push things-ran 'inner-before-each)))
        (t/after (fn [] (array/push things-ran 'inner-after)))
        (t/after-each (fn [] (array/push things-ran 'inner-after-each)))
        (t/test
          "inner test (fail)"
          (fn []
            (array/push things-ran 'inner-test-1)
            (assert false)))
        (t/test
          "inner test (pass)"
          (fn []
            (array/push things-ran 'inner-test-2)
            (assert true)))))

    (t/test
      "outer test (pass)"
      (fn []
        (array/push things-ran 'outer-test-2)
        (assert true)))))

(let [{:counts counts} (t/run-tests :exit-on-failure false)]
  (assert-things-ran
    '[outer-before

      outer-before-each
      outer-test-1
      outer-after-each

      outer-before-each

      inner-before
      inner-before-each
      inner-test-1
      inner-after-each
      inner-before-each
      inner-test-2
      inner-after-each
      inner-after

      outer-after-each

      outer-before-each
      outer-test-2
      outer-after-each

      outer-after])

  (assert (= (counts :failed) 2))
  (assert (= (counts :passed) 2)))


################################################################################
# TODO: os/exit is called (spawn process to assert this)
################################################################################

