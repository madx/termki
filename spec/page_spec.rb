describe TermKi::Page do

  MockRevision = Struct.new(:checksum, :contents, :timestamp)
  class MockRevision; def bind(page) end end

  describe 'initialization' do
    it 'initializes with a name' do
      page = TermKi::Page.new('page')
      page.name.should == 'page'
      page.revisions.should.be.kind_of Hash
      page.revisions.should.be.empty
    end

    it 'has name and revisions read-only attributes' do
      page = TermKi::Page.new('page')
      [:name, :revisions].each do |meth|
        page.should.respond_to     meth
        page.should.not.respond_to "#{meth}="
      end
    end

    it 'has mode an groups read-write attributes' do
      page = TermKi::Page.new('page')
      [:mode, :mode=, :groups, :groups=].each do |meth|
        page.should.respond_to meth
      end
      page.mode.should == :open
      page.groups.should.be.empty?
    end
  end

  before do
    @page = TermKi::Page.new('page')
    @rev  = MockRevision.new('abcd', "Contents", Time.now)
  end

  describe '#push(rev)' do
    it 'adds a revision' do
      @page.push @rev
      @page.revisions.should.include @rev.checksum
      @page.revisions[@rev.checksum].contents.should == @rev.contents
    end

    it 'should not duplicate entries' do
      2.times { @page.push(@rev) }
      @page.revisions.keys.size.should == 1
      @page.revisions.should.include @rev.checksum
    end

    it 'should not overwrite a revision' do
      @page.push @rev
      @page.push MockRevision.new(@rev.checksum, "Fake", Time.now)
      @page.revisions[@rev.checksum].contents.should == @rev.contents
    end

    it 'is aliased as <<' do
      lambda { @page << @rev }.should.not.raise
    end

  end

  describe '#latest()' do
    it 'returns the latest revision' do
      4.times do |i|
        @latest = MockRevision.new("rev#{i}", "Contents #{i}", Time.now + i*10)
        @page.push @latest
      end
      @page.latest.checksum.should == @latest.checksum
    end

    it 'returns nil if there are no revisions' do
      @page.latest.should.be.nil
    end
  end

  describe '#revision(checksum)' do
    before do
      @page << @rev
    end

    it 'returns the given revision' do
      @page.revision('abcd').checksum.should == 'abcd'
    end

    it 'accepts short checksums' do
      @page.revision('ab').checksum.should == 'abcd'
    end

    it 'raises an error if the checksum is ambiguous' do
      @page.push MockRevision.new('abdc', "Contents", Time.now)
      lambda {
        @page.revision('ab')
      }.should.raise RuntimeError, "ambiguous revision ab"
    end

    it 'returns nil if there is no such revision' do
      @page.revision('void').should.be.nil
    end

    it 'is aliased as []' do
      @page['abcd'].should == @page.revision('abcd')
    end
  end

end
