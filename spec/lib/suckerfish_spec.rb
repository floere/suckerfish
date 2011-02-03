require 'spec_helper'

describe Suckerfish do
  
  it 'can only be instantiated with a block' do
    lambda { Suckerfish.new }.should raise_error
  end
  it 'can only be instantiated with a block' do
    lambda { Suckerfish.new { } }.should_not raise_error
  end
  
  context 'forked tests' do
    
  end
  
  describe 'allocation' do
    before(:each) do
      @suckerfish = Suckerfish.allocate
    end
    it 'starts the master process on initialize' do
      @suckerfish.should_receive(:start_master_process_thread).once.with()
      
      @suckerfish.send :initialize, &lambda {}
    end
  end
  
  describe 'instance' do
    before(:each) do
      @suckerfish = Suckerfish.new { |a, b, *c| [a, b, c] }
    end
    it 'has a child reader' do
      lambda { @suckerfish.child }.should_not raise_error
    end
    it 'has a parent reader' do
      lambda { @suckerfish.parent }.should_not raise_error
    end
    it 'has a block_to_execute reader' do
      lambda { @suckerfish.block_to_execute }.should_not raise_error
    end
    it 'has a child reader which returns a Pipe end' do
      @suckerfish.child.should be_instance_of(IO)
    end
    it 'has a parent reader which returns a Pipe end' do
      @suckerfish.parent.should be_instance_of(IO)
    end
    it 'has a block_to_execute reader which returns a block' do
      @suckerfish.block_to_execute.should be_instance_of(Proc)
    end
    
    describe 'simulate_with' do
      it 'calls the block correctly' do
        @suckerfish.simulate_with("[:anything, []]").should == [nil,nil,[]]
      end
      it 'calls the block correctly' do
        @suckerfish.simulate_with("[:anything, [1]]").should == [1,nil,[]]
      end
      it 'calls the block correctly' do
        @suckerfish.simulate_with("[:anything, [1,2]]").should == [1,2,[]]
      end
      it 'calls the block correctly' do
        @suckerfish.simulate_with("[:anything, [1,2,3]]").should == [1,2,[3]]
      end
      it 'calls the block correctly' do
        @suckerfish.simulate_with("[:anything, [1,2,3,4]]").should == [1,2,[3,4]]
      end
      it 'does not handle errors' do
        lambda { @suckerfish.simulate_with("[:anything, [") }.should raise_error(SyntaxError)
      end
    end
    
    describe 'messagified' do
      it 'generates the right message' do
        @suckerfish.messagified([]).should == "[#{Process.pid}, []];;;"
      end
      it 'generates the right message' do
        @suckerfish.messagified([1]).should == "[#{Process.pid}, [1]];;;"
      end
      it 'generates the right message' do
        @suckerfish.messagified([1, 'hello', { :a => :b }]).should == "[#{Process.pid}, [1, \"hello\", {:a=>:b}]];;;"
      end
    end
    
    describe 'harakiri' do
      it 'uses QUIT to kill itself' do
        Process.should_receive(:kill).once.with :QUIT, Process.pid
        
        @suckerfish.harakiri
      end
    end
    
    describe 'execute_block_with' do
      it 'delegates to the block_to_execute' do
        @suckerfish.execute_block_with([1,2]).should == [1,2,[]]
      end
      it 'delegates to the block_to_execute' do
        @suckerfish.execute_block_with([1,2,3]).should == [1,2,[3]]
      end
      it 'delegates to the block_to_execute' do
        @suckerfish.execute_block_with([1,2,3,4]).should == [1,2,[3,4]]
      end
    end
    
    describe 'write_parent' do
      before(:each) do
        @parent = stub :parent
        
        @suckerfish.stub! :parent => @parent
      end
      it 'writes the parent in a specific way' do
        @parent.should_receive(:write).once.with :some_message
        
        @suckerfish.write_parent :some_message
      end
    end
    
    describe 'close_child' do
      before(:each) do
        @child = stub :child
        
        @suckerfish.stub! :child => @child
      end
      context 'already closed' do
        before(:each) do
          @child.stub! :closed? => true
        end
        it 'does not close it again' do
          @child.should_receive(:close).never
          
          @suckerfish.close_child
        end
      end
      context 'not closed yet' do
        before(:each) do
          @child.stub! :closed? => false
        end
        it 'closes it' do
          @child.should_receive(:close).once.with
          
          @suckerfish.close_child
        end
      end
    end
    
  end
  
end