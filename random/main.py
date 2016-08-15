import random

quests = []
with open("quests.txt", 'r', encoding='utf-8') as f:
    line = " "
    while len(line) != 0:
        line = f.readline()
        quests.append(line)
with open("quest2", 'r', encoding='utf-8') as f:
    line = " "
    while len(line) != 0:
        line = f.readline()
        quests.append(line)


while True:
    print(random.choice(quests))
    input()