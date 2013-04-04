#!/usr/bin/env ruby

# Read one or more top logs and summarize highest load factors
# for a list of processes to watch

class TopAnalyzer

    def initialize(_process_names, _verbose=false)
        @process_names = _process_names
        @data = { }
        @verbose = _verbose
    end
    
    def init_buckets(log_file)
        @data['file_name'] = log_file
        @data['log_count'] = 0
        @data['start'] = nil
        @data['end'] = nil
        @data['hi_load'] = -1.0
        @data['hi_load_time'] = nil
        @data['all_processes'] = { }
        @process_names.each do |p|
            @data[p] = { }
            @data[p]['hi_cpu'] = -1.0
            @data[p]['hi_cpu_time'] = nil
            @data[p]['hi_mem'] = -1.0
            @data[p]['hi_mem_time'] = nil
            @data[p]['hi_inst'] = -1
            @data[p]['hi_inst_time'] = nil
            @data[p]['inst_count'] = 0
        end
    end

    def collect_proc_inst_data(log_time, cmd, cpu, mem)
        return if cmd.empty?
        @data['all_processes'][cmd] = 1
        @process_names.each do |p|
            if cmd == p
                cpu = cpu.to_f
                if cpu > @data[p]['hi_cpu']
                    @data[p]['hi_cpu'] = cpu
                    @data[p]['hi_cpu_time'] = log_time
                end
                mem = mem.to_f
                if mem > @data[p]['hi_mem']
                    @data[p]['hi_mem'] = mem
                    @data[p]['hi_mem_time'] = log_time
                end
                @data[p]['inst_count'] += 1
            end
        end
    end
    
    def summarize_last_log(log_time)
        @data['start'] = log_time unless @data['start']
        @data['end'] = log_time
        @data['log_count'] += 1
        @process_names.each do |p|
            if @data[p]['inst_count'] > @data[p]['hi_inst']
                @data[p]['hi_inst'] = @data[p]['inst_count']
                @data[p]['hi_inst_time'] = log_time
            end
            @data[p]['inst_count'] = 0
        end
    end
    
    def dump_stats
        puts @data['file_name']
        puts "#{@data['log_count']} logs from #{@data['start']} to #{@data['end']}"
        puts "high load #{@data['hi_load']} at #{@data['hi_load_time']}"
        @process_names.each do |p|
            puts "process #{p}"
            if @data[p]['hi_inst'] == 0
                puts " no instances in top log"
            else
                puts "  high cpu  #{@data[p]['hi_cpu']} at #{@data[p]['hi_cpu_time']}"
                puts "  high mem  #{@data[p]['hi_mem']} at #{@data[p]['hi_mem_time']}"
                puts "  high inst #{@data[p]['hi_inst']} at #{@data[p]['hi_inst_time']}"
            end
        end
        if @verbose
            puts "all processes"
            @data['all_processes'].keys.sort.each do |p|
                puts "  '#{p}'"
            end
        end
    end

    def analyze_log(log_file)
        init_buckets(log_file)
        File.open(log_file, 'r') do |f|
            lno = 0
            log_time = nil
            proc_table = false
            while line = f.gets do
                lno += 1
                line.chomp!
                case line
                when /^$/
                    # puts "#{lno}: blank"
                    proc_table = false
                when /^top\s+-\s+(\d\d:\d\d:\d\d)\s+up.+load average:\s+([0-9.]+),\s+([0-9.]+),\s+([0-9.]+)/
                    # puts "#{lno}: time header"
                    summarize_last_log(log_time) if log_time 
                    proc_table = false
                    log_time = $1
                    load_1 = $2.to_f
                    load_5 = $3.to_f
                    load_15 = $4.to_f
                    if load_1 > @data['hi_load']
                        @data['hi_load'] = load_1
                        @data['hi_load_time'] = log_time
                    end
                when /^\s+PID\s+USER\s+PR\s+NI\s+VIRT\s+RES\s+SHR\s+S\s+\%CPU\s+\%MEM\s+TIME\+\s+COMMAND/
                    # puts "#{lno}: table header"
                    proc_table = true
                    proc_inst = 0
                else
                    if proc_table
                        # row looks like this
                        #    1 root      15   0 10364  740  620 S  0.0  0.0   0:07.05 init    
                        pid, user, pr, ni, virt, res, shr, stat, cpu, mem, time, cmd = line.strip.split(/\s+/, 13)
                        collect_proc_inst_data(log_time, cmd.strip, cpu, mem)
                    end
                end
            end
            summarize_last_log(log_time) if log_time
        end
    end
end

log_file_name = ARGV.shift
a = TopAnalyzer.new(ARGV)
a.analyze_log(log_file_name)
a.dump_stats

