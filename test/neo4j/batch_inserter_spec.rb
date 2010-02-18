$LOAD_PATH << File.expand_path(File.dirname(__FILE__) + "/../../lib")
$LOAD_PATH << File.expand_path(File.dirname(__FILE__) + "/..")

require 'neo4j'
require 'spec_helper'

describe Neo4j::BatchInserter do

  before(:all) { stop }
  after(:each) { stop }

  it "should accept Neo4j::Node.new and Neo4j::Relationship.new" do
    class Foo
      include Neo4j::NodeMixin
    end
    a = b = nil
    Neo4j::BatchInserter.new do |b|
      a = Neo4j::Node.new :name => 'a'
      b = Neo4j::Node.new :name => 'b'
      Neo4j::Relationship.new(:friend, a, b, :since => '2001-01-01')
    end

    Neo4j::Transaction.new
    node_a = Neo4j.load_node(a.neo_id)
    node_a[:name].should == 'a'
    node_a.rel?(:friend).should be_true
    Neo4j::Transaction.finish
  end

  it "should allow creating Neo4j::NodeMixin instances" do
    class Foo
      include Neo4j::NodeMixin
    end

    c = nil
    Neo4j::BatchInserter.new do |b|
      c = Foo.new :key1 => 'val1', :key2 => 'val2'
      c[:key3] = 'val3'
    end

    Neo4j::Transaction.new
    node_c = Neo4j.load_node(c.neo_id)
    node_c[:key1].should == 'val1'
    node_c[:key2].should == 'val2'
    node_c[:key3].should == 'val3'
    node_c.should be_kind_of(Foo)
    Neo4j::Transaction.finish
  end

  it "should expose the ReferenceNode object" do
    Neo4j::BatchInserter.new do |b|
     ref_node = Neo4j.ref_node
     ref_node[:some_prop] = "some value"
     Neo4j::Relationship.new(:friend, ref_node, Neo4j::Node.new, :since => '2001-01-01')
    end
 
    Neo4j::Transaction.run do
      puts "running tx #{Neo4j::Transaction.running?}"
      Neo4j.ref_node.rel?(:friend).should be_true
    end
  end

  it "should be possible to use together with Migrations" do
    pending "Endless recursion since it will trigger running the migration again"
    Neo4j.migration 1, :first do
      up do
        puts "Create batch inserter" + caller.inspect
        Neo4j::BatchInserter.new do 
          Neo4j.ref_node[:first] = true
        end
        Neo4j.start
      end
      down do
        Neo4j.ref_node[:first] = nil
      end
    end

    Neo4j.migrate!
    
    Neo4j::Transaction.run do
      Neo4j.ref_node[:first].should be_true
      Neo4j.db_version.should == 1
    end
  end

end
