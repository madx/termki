this = File.dirname(__FILE__)
require File.join(this, 'lib', 'termki')

wiki = if db = File.exist?(File.join(File.dirname(__FILE__), 'wiki.db'))
  File.open(db, 'r') { |data| TermKi::Wiki.load data }
else nil end

run TermKi::App.new(wiki)
