import random

def generate_gift_swap(participants):
    """Generates a gift swap pairing for the given participants."""

    # Create a shuffled copy of the participants
    shuffled = participants.copy()
    random.shuffle(shuffled)

    # Pair each participant with the next in the shuffled list
    pairs = {}
    for i in range(len(participants)):
        giver = participants[i]
        receiver = "none"
        while True:
          receiver = shuffled[(i + 1) % len(participants)]  # Wrap around to the start
          if giver != receiver:
            pairs[giver] = receiver
            break

    return pairs

if __name__ == "__main__":
    # Get participant names
    participants = ['Autumn', 'Dalton', 'Izzy', 'Aiden', 'Ethan', 'Luke', 'Penelope', 'Adeline', 'Eloise', 'Hazel']

    # Generate and print the pairs
    pairs = generate_gift_swap(participants)
    for giver, receiver in pairs.items():
        print(f"{giver} will give a gift to {receiver}.")