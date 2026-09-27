# Royal Cards

Flutter Android virtual-coin card-game practice project with Firebase rooms, friends, invites and real-time game state.

## Included
- Rummy, Teen Patti, Poker and Andar Bahar practice tables
- Firebase anonymous authentication
- User profile with name, email and phone fields
- Friends and friend requests
- Online rooms and real-time room players
- Friend game invites
- Real-time turn/game-state updates
- Virtual wallet and activity history
- Leaderboard screen
- GitHub Actions APK build

## Important Firebase setup
1. Enable **Authentication → Sign-in method → Anonymous** in the `royal-cards-project` Firebase project.
2. Create/enable **Cloud Firestore**.
3. Publish `firestore.rules` as the Firestore rules.
4. Keep `google-services.json` in the project root; the GitHub workflow copies it into `android/app/` after generating the Android folder.

This project is for virtual coins/practice only. It does not implement real-money deposits, withdrawals, wagering or cash prizes.
