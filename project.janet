(declare-project
 :name "sofa"
 :author "Elliott Shugerman <eeshugerman@gmail.com>"
 :description "A testing library, insired by Mocha"
 :license "MIT"
 :url "https://github.com/eeshugerman/sofa"
 :repo "git+https://github.com/eeshugerman/sofa"
 # currently just need this for janet-format
 :dependencies ["https://github.com/janet-lang/spork"]
 )

(declare-source
 :prefix "sofa"
 # :source ["src/"] # wonder if this works?
 :source ["src/init.janet" "src/core.janet" "src/syntax.janet"])

# TODO declare-binsrcipt? https://github.com/ianthehenry/judge/blob/master/project.janet#L25
