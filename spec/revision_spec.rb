describe TermKi::Revision do

  describe 'initialization' do
    before do
      @rev = TermKi::Revision.new('Contents')
    end
    it 'initializes with contents' do
      @rev.contents.should == 'Contents'
      @rev.should.be.kind_of TermKi::Revision
    end

    it 'sets the timestamp' do
      @rev.timestamp.should.be.kind_of Time
    end

    it 'does not set the checksum' do
      @rev.checksum.should.be.nil
    end

    it 'has contents, timestamp and checksum read-only attributes' do
      [:contents, :timestamp, :checksum].each do |meth|
        @rev.should.respond_to     meth
        @rev.should.not.respond_to "#{meth}="
      end
    end
  end

  describe '#bind(page)' do
    before do
      @rev  = TermKi::Revision.new('Contents')
      @page = Struct.new(:name).new('page')
    end

    it 'sets the checksum' do
      @rev.bind @page
      @rev.checksum.should =~ /\A[a-f0-9]{64}\Z/
    end

    it 'adds object_id to the checksum to avoid collisions' do
      rev1 = TermKi::Revision.new('Contents')
      rev1.bind(@page)
      rev1.checksum.should == Digest::SHA2.hexdigest([
        rev1.object_id,
        @page.name,
        rev1.timestamp.to_i
      ].join('+'))
    end

    it 'raises an error if the checksum is already set' do
      @rev.bind @page
      lambda {
        @rev.bind @page
      }.should.raise RuntimeError, "already bound to #{@page.name}"
    end
  end

  describe '#render' do
    it 'outputs a pretty version of the revision' do
      rev = TermKi::Revision.new("Contents")
      rev.bind Struct.new(:name).new('page')
      output = rev.render
      output.should.include rev.checksum
      output.should.include rev.timestamp.xmlschema
      output.should.include rev.contents
    end
  end

end
