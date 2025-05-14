import sys

# Get the team name from command line arguments
team_name = sys.argv[1] if len(sys.argv) > 1 else "No team name provided"
print(f"Hello, {team_name}!")
