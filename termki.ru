this = File.dirname(__FILE__)

require File.join(this, 'lib', 'termki')

TermKi::ACL.load(YAML.load_file(File.join(this, 'users.yml')))
TermKi.set :store, File.join(this, 'wiki.db')

TermKi.setup!

run TermKi
