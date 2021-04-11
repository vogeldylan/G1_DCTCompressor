# SSH Tunnelling from DESL Machines

This process will let you connect your local computer to a remote target on the DESL machines.


## Procedure to install

1. Ensure that you have the SSH server service installed on your machine, see [here](https://www.hanselman.com/blog/how-to-ssh-into-a-windows-10-machine-from-linux-or-windows-or-anywhere) for instructions 
    - Note, I don't recommend setting the SSH server to start on boot, like they specify. Seems unsafe.
2. (Optional) Harden your SSH config, some recommendations [here](https://blog.devolutions.net/2017/4/10-steps-to-secure-open-ssh) 
    - Note, the publickey step probably isn't ideal here because you'd need to transfer your publickey to all the DESL machines. Just use a strong password.
3. Open a port forwarding rule on your router (if applicable) and point to your local machine. Remember to use the port ***p*** you specified in Step 2 (preferably not 22, as attackers do scan for open port 22)
4. Create an accept rule in Windows firewall
    - Only specify the rule for connections on port ***p*** via TCP
    - Only allow remote machines from the UofT DESL machines (ip: `X.X.X.0/24`)
    - Follow this guide for help: https://superuser.com/questions/1087392/windows-firewall-blocking-ssh-to-secondary-subnet
5. (Note) If you ever want to monitor connections to your computer, you can check out Event Viewer on Windows and look for the SSH Server logs
6. (Note) What we're going to do is to create an SSH tunnel from DESL to your machine. Refer to [this](https://www.fireeye.com/blog/threat-research/2019/01/bypassing-network-restrictions-through-rdp-tunneling.html) page for more information. 

## Connection Setup:

1. Open powershell as admin. Start the SSH server on your local machine by calling: `Start-Service sshd`
2. Log in to the DESL machines via RDP, using your normal login
3. Start the hardware server by calling 
    - `C:\DESL\Xilinx\Vivado\2018.3\bin\hw_server.bat`. 
    - Note, I recommend creating a shortcut to the file on your desktop
4. Call: `plink.exe <users>@<IP or domain>  -P <***p***> -2 -4 -T -N -C -R 3121:127.0.0.1:3121`
    - Replace `<users>` with your Windows username
    - Replace `<IP or domain>` with the public IP of your router or computer
    - Replace `<***p***>` with the public port you're forwarding or using for SSH, depending on your config.
    - Learn more about the flags [here](https://www.ssh.com/ssh/putty/putty-manuals/0.68/Chapter7.html#plink-options) 
    - Note, you can use any port (not just 3121) but you need to launch hw_server with the correct option
    - Note, you will be prompted for the password and then no shell will come up. This is specified by the -N option, which tells plink not to start a shell
5. Open Hardware Manager in Vivado. Specify that you'd like to connect to a remote host, and enter `localhost` for the hostname and `3121` for the port (or whatever you started it as).
6. The remote FPGA should now appear! You can now program the DESL machines from your computer.
7. Remember to close everything after you finish.