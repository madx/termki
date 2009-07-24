require 'time'
require 'zlib'
require 'rackable'
require 'digest/sha2'

module TermKi

  class App
    include Rackable

    attr_reader :wiki

    def initialize(base_wiki=nil)
      if base_wiki.nil?
        @wiki = Wiki.new
        homepage = Page.new('home')
        homepage << Revision.new('Welcome to TermKi!')
        wiki.add(homepage)
      else
        @wiki = base_wiki
      end
    end

    def get(name=nil,rev=nil)
      case name
        when '_index_': index
        else page(name, rev)
      end
    end

    def post(name)
      http_error 403, "Can't create '#{name}': already exists" if wiki[name]
      if %w[__index__].include?(name)
        http_error 403, "'#{name}' is reserved"
      end
      if body = rack.data[:body]
        page = Page.new(name)
        page << Revision.new(body)
        wiki.add page
        page.latest.render
      else
        http_error 500, "Can't create '#{name}': missing body"
      end
    end

    def put(name)
      http_error 404, "No such page '#{name}'" unless wiki[name]
      if body = rack.query[:body] || rack.data[:body]
        rev = Revision.new(body)
        wiki[name] << rev
        wiki[name].latest.render
      else
        http_error 500, "Can't update '#{name}': missing body"
      end
    end

    def delete(name)
      http_error 404, "No such page '#{name}'" unless wiki[name]
      wiki.destroy(name)
      nil
    end

    private

    def index
      String.new.tap do |out|
        wiki.index.keys.sort.each do |name|
          out << wiki[name].latest.render(:no_contents)
        end
      end
    end

    def history(page)
      String.new.tap do |out|
        page.history.each do |rev|
          out << rev.render(:no_contents)
        end
      end
    end

    def page(name, rev)
      if name.nil?
        wiki['home'].latest.render(*rack.query.keys)
      else
        page = wiki[name] || http_error(404, "No such page '#{name}'")
        return history(page) if rev == 'history'
        rev ||= page.latest.checksum
        begin
          if page[rev]
            page[rev].render(*rack.query.keys)
          else
            http_error(404, "No such revision '#{rev}'")
          end
        rescue RuntimeError => e
          http_error 400, e.message
        end
      end
    end
  end


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
    attr_reader :name, :history

    def initialize(name)
      fail "wrong name" unless name =~ /^[a-zA-Z0-9_:\+-]+$/
      @name = name
      @history = []
    end

    def update(rev)
      history.unshift rev unless history.member? rev
      rev.bind self
    end
    alias << update

    def latest
      history.first
    end

    def revision(checksum)
      fail 'not a portion of SHA2' unless checksum =~ /\A[a-fA-F0-9]+\Z/
      matches = history.select {|r| r.checksum =~ Regexp.new("^#{checksum}") }

      case matches.size
        when 0: nil
        when 1: matches.first
        else    fail "ambiguous revision #{checksum}"
      end
    end
    alias [] revision
  end


  class Revision
    attr_reader :contents, :timestamp, :checksum, :page

    def initialize(contents)
      @contents  = contents
      @checksum  = nil
      @timestamp = Time.now
    end

    def bind(page)
      fail "already bound to #{page.name}" if @checksum
      @page     = page
      @checksum = Digest::SHA2.hexdigest([
        object_id,
        page.name,
        timestamp.to_i
      ].join('+'))
    end

    def render(*opts)
      String.new.tap do |out|
        unless opts.include? :no_header
          out << "Resource: #{page.name}\n"
          out << "Checksum: #{checksum}\n"
          out << "Timestamp: #{timestamp.xmlschema}\n"
          out << "---\n"
        end
        out << contents unless opts.include? :no_contents
      end
    end
  end
end
