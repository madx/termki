require File.join(File.dirname(__FILE__), 'lib', 'termki')

TermKi::App.store_to File.join(File.dirname(__FILE__), 'wiki.db')

run TermKi::App.new
