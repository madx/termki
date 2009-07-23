describe TermKi::Page do

  MockRevision = Struct.new(:checksum, :contents, :timestamp)
  class MockRevision; def bind(page) end end

  describe 'initialization' do
    it 'initializes with a name' do
      page = TermKi::Page.new('page')
      page.name.should == 'page'
      page.history.should.be.kind_of Array
      page.history.should.be.empty
    end

    it 'has name and history read-only attributes' do
      page = TermKi::Page.new('page')
      [:name, :history].each do |meth|
        page.should.respond_to     meth
        page.should.not.respond_to "#{meth}="
      end
    end
  end

  before do
    @page = TermKi::Page.new('page')
    @rev  = MockRevision.new('abcd', "Contents", Time.now)
  end

  describe '#update(rev)' do
    it 'adds a revision' do
      @page.update @rev
      @page.history.should.include @rev
      @page.history.first.should == @rev
    end

    it 'should not duplicate entries' do
      2.times { @page.update(@rev) }
      @page.history.size.should == 1
      @page.history.map {|r| r.checksum }.should.include @rev.checksum
    end

    it 'is aliased as <<' do
      lambda { @page << @rev }.should.not.raise
    end

  end

  describe '#latest()' do
    it 'returns the latest revision' do
      4.times do |i|
        @latest = MockRevision.new("rev#{i}", "Contents #{i}", Time.now + i*10)
        @page.update @latest
      end
      @page.latest.checksum.should == @latest.checksum
    end

    it 'returns nil if there are no history' do
      @page.latest.should.be.nil
    end
  end

  describe '#revision(checksum)' do
    before do
      @page << TermKi::Revision.new("contents")
      @cksm = @page.history.first.checksum
    end

    it 'fails if checksum is not a portion of SHA2' do
      lambda {
        @page.revision('void')
      }.should.raise RuntimeError, 'not a portion of SHA2'
    end

    it 'returns the given revision' do
      @page.revision(@cksm).checksum.should == @cksm
    end

    it 'accepts short checksums' do
      @page.revision(@cksm[0..2]).checksum.should == @cksm
    end

    it 'raises an error if the checksum is ambiguous' do
      checksum = @cksm[0..60] + 'BAD'
      @page.update MockRevision.new(checksum, "Contents", Time.now)
      lambda {
        @page.revision(@cksm[0..2])
      }.should.raise RuntimeError, "ambiguous revision #{@cksm[0..2]}"
    end

    it 'returns nil if there is no such revision' do
      @page.revision(@cksm.next).should.be.nil
    end

    it 'is aliased as []' do
      @page[@cksm].should == @page.revision(@cksm)
    end
  end

end
