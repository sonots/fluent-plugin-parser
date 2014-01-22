require_relative '../helper'
require 'benchmark'
Fluent::Test.setup

def create_driver(config, tag = 'foo.bar')
  Fluent::Test::OutputTestDriver.new(Fluent::ParserOutput, tag).configure(config)
end

# setup
time = Time.now.to_i
CONFIG = %[
  add_prefix parsed
  key_name message
  time_parse false
]
ltsv_message = {'message' => "time:2013-11-20 23:39:42 +0900\tlevel:ERROR\tmethod:POST\turi:/api/v1/people\treqtime:3.1983877060667103"}
ltsv_driver = create_driver(CONFIG + %[format ltsv])
tsv_message = {'message' => "2013-11-20 23:39:42 +0900\tERROR\tPOST\t/api/v1/people\t3.1983877060667103"}
tsv_driver = create_driver(CONFIG + %[format tsv\nkeys time,level,method,uri,reqtime])
regex_message = {'message' => "time:2013-11-20 23:39:42 +0900\tlevel:ERROR\tmethod:POST\turi:/api/v1/people\treqtime:3.1983877060667103"}
regex_driver = create_driver(CONFIG + %[format /^(?<time>[^\t]*)(?<level>[^\t]*)(?<method>[^\t]*)(?<uri>[^\t]*)(?<reqtime>[^\t]*)/])

# bench
n = 100000
Benchmark.bm(7) do |x|
  x.report("ltsv")  { ltsv_driver.run  { n.times { ltsv_driver.emit(ltsv_message, time)  } } }
  x.report("tsv")   { tsv_driver.run  { n.times { tsv_driver.emit(tsv_message, time)  } } }
  x.report("regex") { regex_driver.run  { n.times { regex_driver.emit(regex_message, time)  } } }
end
