# This is an interface that provides the user of
# with the possibility to change parameters
# while the application is running.
#
# Important Note:
# This will only work in Master/Child configurations.
# Like in an application running in Unicorn.
#
class Suckerfish
  
  attr_reader :child, :parent, :block_to_execute
  
  def initialize &block_to_execute
    raise 'Suckerfish needs a block to tell it what to do in the master process.' unless block_given?
    @child, @parent   = IO.pipe
    @block_to_execute = block_to_execute
    start_master_process_thread
  end
  
  # This runs a thread that listens to child processes.
  #
  def start_master_process_thread
    # This thread is stopped in the children.
    #
    Thread.new do
      loop do
        # Wait for input from the child.
        #
        IO.select([child], nil, nil, 2) or next
        
        # Get the message from the child.
        #
        result = child.gets ';;;'
        
        # Evaluate and split what the child sent.
        #
        child_pid, args = eval result
        
        # It needs to be an array of params.
        #
        next unless Array === args # TODO Rewrite to to_ary?
        
        # Execute the block with the given parameters.
        #
        execute_block_with *args
        
        # Kill off all the workers with the old parameters.
        #
        kill_each_worker_except child_pid
        
      # TODO rescue on error.
        
      end
    end
  end
  
  # Returns all the worker pids.
  #
  # Note: This will eventually need to be web server agnostic.
  #
  def worker_pids
    Unicorn::HttpServer::WORKERS.keys
  end
  
  #
  #
  # Note: Body taken from Unicorn.
  #
  def kill_each_worker_except pid
    worker_pids.each do |wpid|
      next if wpid == pid
      kill_worker :KILL, wpid
    end
  end
  def kill_worker signal, wpid
    Process.kill signal, wpid
    exclaim "Killing worker ##{wpid} with signal #{signal}."
  rescue Errno::ESRCH
    remove_worker wpid
  end
  
  # Remove the worker with the given pid.
  #
  # Note: This will eventually need to be web server agnostic.
  #
  def remove_worker worker_pid
    worker = Unicorn::HttpServer::WORKERS.delete(worker_pid) and worker.tmp.close rescue nil
  end
  
  # This first tries to update in the child process,
  # and if successful, in the parent process.
  #
  # TODO Alias? Rename?
  #
  def process *parameters
    # Close the child, maybe.
    #
    close_child
    
    # Convert into a message.
    #
    message = messagified parameters
    
    # Simulate the sending of the message
    # in the child and running the block.
    #
    # This might fail.
    #
    simulate_with parameters
    
    # Success! Write the parent.
    #
    write_parent message
    
    # Return the result.
    #
    result
  rescue StandardError => e
    # I need to die such that my broken config is never used.
    #
    # Note: The assumption is that this fails in the Unicorn child
    #       if it would fail in the master!
    #
    harakiri
    
    # Reraise to the user of Suckerfish.
    #
    raise e
  end
  
  # Simulates the sending and executing of the block
  # as it would be in the parent.
  #
  # If it doesn't fail, good.
  #
  def simulate_with message
    # Try to eval the message given.
    #
    _, parameters = eval message
    
    # Try to execute it.
    #
    # Dup if someone is trying to be clever?
    #
    execute_block_with parameters
  end
  
  # Translates the parameters into a message that can be sent to the parent.
  #
  def messagified parameters
    %Q{#{[Process.pid, parameters]};;;}
  end
  
  # Kills itself, but still "answering" the received request honorably.
  #
  def harakiri
    Process.kill :QUIT, Process.pid
  end
  
  # Write the parent.
  #
  # Note: The ;;; is the end marker for the message.
  # TODO: Clever? Too clever?
  #
  # TODO: Problematic if you want to pass objects that can't be reevaluated from the string.
  #       I actually need to also eval this string in the child.
  #
  def write_parent message
    parent.write message
  end
  
  # Close the child if it isn't yet closed.
  #
  def close_child
    child.close unless child.closed?
  end
  
  # Tries running the block in the child process or parent process.
  #
  def execute_block_with parameters
    block_to_execute.call *parameters
  end
  
end