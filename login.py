import pxssh
import sys

ipfile = open (str(sys.argv[1]),"r")
with open (str(sys.argv[2]),"r") as cmdfile:
     cmds = cmdfile.readlines()
user = sys.argv[3]
pw = sys.argv[4]
s = ""

for ip in ipfile:
     print (ip)
     session = pxssh.pxssh()
     if not session.login (ip, user, pw):
          print "SSH session failed on login."
          print str(session)
     else:
          print "SSH session login successful"
          for cmd in cmds:
               
              session.sendline (cmd)
              session.prompt()         # match the prompt
              print session.before
              session.prompt()
              print session.before     # print everything before the prompt.                  
          session.logout()


