require 'sinatra/base'
require 'digest/sha1'
require 'zlib'

class TermKi < Sinatra::Base

  class Wiki
    attr_reader :index

    def self.load(fileish)
      Marshal.load(Zlib::Inflate.inflate(fileish.read))
    end

    def initialize
      @index = {}
    end

    def [](name)
      @index[name]
    end

    def add(page)
      fail "\"#{page.name}\" is already in the index" if @index[page.name]
      @index[page.name] = page
    end

    def destroy(name)
      @index.delete(name) { |el| fail "no such page \"#{el}\"" }
    end

    def dump(fileish)
      fileish << Zlib::Deflate.deflate(Marshal.dump(self))
    end
  end


  class Page
    attr_reader :name, :revisions

    def initialize(name)
      @name = name
      @revisions = {}
    end

    def push(rev)
      rev.bind self
      @revisions[rev.checksum] ||= rev
    end
    alias << push

    def latest
      @revisions.values.max { |a,b| a.timestamp <=> b.timestamp }
    end

    def history
      @revisions.values.sort { |a,b|
        a.timestamp <=> b.timestamp
      }.reverse
    end

    def revision(checksum)
      matches = @revisions.keys.select do |rev|
        rev =~ Regexp.new("^#{checksum}")
      end

      case matches.size
        when 0: nil
        when 1: @revisions[matches.first]
        else    fail "ambiguous revision #{checksum}"
      end
    end
    alias [] revision
  end


  class Revision
    attr_reader :contents, :timestamp, :checksum

    def initialize(contents)
      @contents  = contents
      @checksum  = nil
      @timestamp = Time.now
    end

    def bind(page)
      fail "already bound to #{page.name}" if @checksum
      @checksum = Digest::SHA1.hexdigest([
        rand,
        page.name,
        @timestamp.to_i
      ].join('+'))
    end
  end


  # App
  configure do
    set :store, 'wiki.db'
  end

  @@wiki = nil
  def wiki() @@wiki end

  def self.setup!
    if File.file?(store)
      @@wiki = File.open(store, 'r') { |f| Wiki.load(f) }
    else
      @@wiki = Wiki.new
      home = Page.new('home')
      rev = Revision.new('This is the default TermKi home page')
      home << rev
      @@wiki.add(home)
    end
  end

  helpers do
    def render(page, rev)
      String.new.tap { |out|
        out << "Resource: /#{page.name}/#{rev.checksum}\n"
        out << "Modified: #{rev.timestamp.xmlschema}\n"
        out << "---\n"
        out << "#{rev.contents}"
      }
    end

    def valid_page!
      unless @page = wiki[params[:page]]
        throw :halt, [404, "Page '%s' not found" % params[:page] ]
      end
    end

    def valid_rev!
      unless @rev = @page[params[:rev]]
        throw :halt, [404, "Revision %s not found for page '%s'" %
                           [ params[:rev], params[:page] ] ]
      end
    end

  end

  before do
    content_type 'text/plain'
  end

  get '/__commit__' do
    begin
      File.open(options.store, 'w+') { |s| wiki.dump(s) }
      "Changes have been commited"
    rescue => e
      "Error during commit: #{e.message}"
    end
  end

  get '/__index__' do
    (buffer = "").tap do |buf|
      wiki.index.each do |name, page|
        latest = page.latest
        count  = page.revisions.size
        buf << "Resource: /#{name}/#{latest.checksum}"
        buf << " (#{count} revision#{count == 1 ? '' : 's'})\n"
        buf << "Modified: #{latest.timestamp.xmlschema}\n"
        buf << "---\n"
      end
    end

    buffer
  end

  get '/' do
    redirect '/home'
  end

  get '/:page' do
    valid_page!

    render @page, @page.latest
  end

  get '/:page/:rev' do
    valid_page!
    valid_rev!

    render @page, @rev
  end

  post '/:page' do
    page = Page.new(params[:page])
    page << (rev = Revision.new(params[:contents]))

    begin
      wiki.add page
    rescue RuntimeError => e
      throw :halt, [500, e.message]
    end

    render page, rev
  end

  put '/:page' do
    valid_page!

    @page << (rev = Revision.new(params[:contents]))

    render @page, rev
  end

  delete '/:page' do
    valid_page!

    if params[:page] == 'home'
      throw :halt, [500, "You can't destroy the home page"]
    end
    wiki.destroy params[:page]

    "Page '#{params[:page]}' has been destroyed"
  end

  delete '/:page/:rev' do
    valid_page!
    valid_rev!

    if params[:page] == 'home' && @page.revisions.size == 1
      throw :halt, [500, "You can't destroy the home page"]
    end

    @page.revisions.delete(@rev.checksum)

    out = "Revision #{params[:rev]} has been destroyed"
    if @page.revisions.empty?
      wiki.destroy @page.name
      out << "\nPage '#{@page.name}' has been destroyed"
    end
    out + "\n"
  end

end
