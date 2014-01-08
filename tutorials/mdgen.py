import os

final = []

with open('blurb.md', 'r') as b:
    print b.read()

for f in os.listdir('.'):
    if f[0] == '0':
        with open(f, 'r') as bash_file:
            bash = bash_file.read().split('\n')
            for line in bash:
                if len(line) > 0:
                    # Comments
                    if line[:2] == '##':
                        line = '##' + line
                    elif line[0] == '#':
                        line = line[2:] + '\n'
                    else:
                        line = "    " + line
                print line
            
