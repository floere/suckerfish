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
        
        # Get the message.
        #
        result = child.gets ';;;'
        
        #
        #
        pid, args = eval result
        
        # It needs to be an array of params.
        #
        next unless Array === args # TODO Rewrite to to_ary?
        
        # Execute the block with the given parameters.
        #
        execute_block_with *args
        
        #
        #
        kill_each_worker_except pid
        
      # TODO rescue on error.
        
      end
    end
  end
  
  # TODO This needs to be webserver agnostic.
  #
  def worker_pids
    Unicorn::HttpServer::WORKERS.keys
  end
  
  # Taken from Unicorn.
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
  # TODO This needs to be Webserver agnostic.
  #
  def remove_worker wpid
    worker = Unicorn::HttpServer::WORKERS.delete(wpid) and worker.tmp.close rescue nil
  end
  
  # This first tries to update in the child process,
  # and if successful, in the parent process
  #
  # TODO Alias?
  #
  def process *args
    # Close the child, maybe.
    #
    close_child
    
    # Try to execute it.
    #
    result = execute_block_with *args # Dup if someone is trying to be clever?
    
    # Success! Write the parent.
    #
    write_parent args
    
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
    
    # Reraise to the user.
    #
    raise e
  end
  
  # Kills itself, but still "answering" the request honorably.
  #
  def harakiri
    Process.kill :QUIT, Process.pid
  end
  
  # Write the parent.
  #
  # Note: The ;;; is the end marker for the message.
  # TODO: Clever? Too clever?
  #
  def write_parent parameters
    parent.write "#{[Process.pid, parameters]};;;"
  end
  
  # Close the child if it isn't yet closed.
  #
  def close_child
    child.close unless child.closed?
  end
  
  # Tries running the block in the child process or parent process.
  #
  def execute_block_with *args
    block_to_execute.call *args
  end
  
end