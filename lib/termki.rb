require 'rackable'
require 'digest/sha2'
require 'zlib'

module TermKi

  class App
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
    attr_reader :contents, :timestamp, :checksum

    def initialize(contents)
      @contents  = contents
      @checksum  = nil
      @timestamp = Time.now
    end

    def bind(page)
      fail "already bound to #{page.name}" if @checksum
      @checksum = Digest::SHA2.hexdigest([
        object_id,
        page.name,
        timestamp.to_i
      ].join('+'))
    end
  end


  class User
    attr_reader :password, :groups

    def initialize(password, groups)
      @password, @groups = password, groups || []
    end

    def in_groups?(groups)
      groups.any? {|g| @groups.include?(g) }
    end

    def admin?
      groups.include?('wheel')
    end
  end
end
