require File.join(File.dirname(__FILE__), 'lib', 'termki')

TermKi.set :store, File.join(File.dirname(__FILE__), 'wiki.db')

TermKi.setup!

run TermKi
