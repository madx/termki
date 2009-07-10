describe TermKi::Wiki do

  before do
    @wiki = TermKi::Wiki.new
    @page = TermKi::Page.new('page')
  end

  describe 'initialization' do
    it 'creates a wiki with an empty index' do
      @wiki.index.should.be.kind_of Hash
      @wiki.index.should.be.empty
    end
  end

  describe '#[](page)' do
    it 'returns the page if it exists' do
      @wiki.index['page'] = :mock
      @wiki['page'].should == :mock
    end

    it 'returns nil if the page does not exist' do
      @wiki['void'].should.be.nil
    end
  end

  describe '#add(page)' do
    it 'adds a page to the index' do
      @wiki.add @page
      @wiki['page'].should.be.kind_of TermKi::Page
    end

    it 'fails if there is already a page with this name' do
      @wiki.add @page
      lambda { @wiki.add @page }.should.
        raise RuntimeError, '"page" is already in the index'
    end
  end

  describe '#destroy(page)' do
    it 'destroys the given page' do
      @wiki.add @page
      @wiki.destroy 'page'
      @wiki.index.should.be.empty
    end

    it 'fails if there is no such page' do
      lambda { @wiki.destroy('page') }.should.
        raise RuntimeError, 'no such page "page"'
    end
  end

  describe 'dumping and loading' do
    before do
      @wiki.add @page
      @page << TermKi::Revision.new('Hello, world')
      @io = StringIO.new
      @wiki.dump(@io)
    end

    describe '#dump(fileish)' do
      it 'compresses the wiki and write in the file' do
        @io.string.should.not.be.empty
        @io.size.should.be < Marshal.dump(@wiki).size
      end
    end

    describe '.load(fileish)' do
      it 'returns the uncompressed wiki as a Ruby object' do
        @io.rewind
        dump = TermKi::Wiki.load(@io)
        dump['page'].should.not.be.nil
        dump['page'].latest.checksum.should == @wiki['page'].latest.checksum
      end
    end
  end

end
