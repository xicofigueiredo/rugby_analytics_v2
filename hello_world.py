import sys
import json
import pandas as pd

# Get the JSON data from command line argument
try:
    data = json.loads(sys.argv[1])
except Exception as e:
    print(json.dumps({"error": str(e)}))
    sys.exit(1)

# Create a list of dictionaries for the DataFrame
team_players = []
for team, players in zip(data['teams'], data['players']):
    for player in players:
        team_players.append({
            'Team': team,
            'Player': player
        })

# Create DataFrame
df = pd.DataFrame(team_players)

# Get team with most players
team_counts = df['Team'].value_counts()
team_with_most_players = team_counts.index[0]
number_of_players = team_counts.iloc[0]

# Create the output dictionary
output = {
    "team_with_most_players": team_with_most_players,
    "number_of_players": int(number_of_players),
    "players": df[df['Team'] == team_with_most_players]['Player'].tolist()
}

# Print as JSON
print(json.dumps(output))
