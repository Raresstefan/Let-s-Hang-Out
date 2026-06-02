Task:
Build a Flutter app (should be available for IOS, Android, Web) for a social network that facilitates socialising activities for people:
User cases:

Ex1: Mihai (Persona 1) wants to go out for some drinks. Joins the app and creates the activity. The activity has a start date, description and a place suggestion for hosting the activity, all these details must be entered by the host. After mihai created the activity, he as the host will receive notifications whenever a new user wants to join the activity, he can accept/deny. After at least one more user joins the activity (2 users at least including Mihai) a private chat will be created where they can talk and plan further their activity. Whenever a new user joins the activity he will get on the group chat as well.

Ex2: Radu wants to play tennis but his close friends aren't available when he is. He joins the app and creates a new activity typing in the description: tenis match 2 hours. He gets a request from someone else, he accepts, both of them get on the chat and plan this further.

For new users: Rares found out about this new app that get people closer and eliminates social anxiety when it comes to talk with new people. He does not have any idea for creating a new activity, so he is curious to see what other people created as activities. He scrolls through the activities and finds one that he likes, he clicks the join button and immediately gets in the group chat. Rares also gets some default suggestions from the app based on the most often done activities. The app will suggest them. It will see a message like: Some of the people liked this / signed up for this and the activities will be listed in a scrollable way, like the videos from tik tok. The host will have the control to remove people from the group chat/activity if he detects something suspicious about them.

Now that you got the idea let's focus on the criterias that the app has to implement:

1. Functionality / Capabilites of the app:
Users can create new activities, can signup on others activities, will see recommended activities based on what most of the users chose and rated it as fun, Users will be able to rate the activities they participated in, they will receive a notification from the app 2 hours from the starting time of the activity, they will be able to add friends people with who they went out with. Users will be able to have friends lists, just like on Facebook app, they will be able to chat with their friends. Users will be able to chat with the people that are signed up in the same activity as them. After the activity finish, the group chat will not dissapear, they will be able to chat there further.

2. Design:
Each activity will be represented as a Card, on this Card the user will see a background picture that will be added by the host when creating the activity, will see the title of the activity and the current number of people enrolled in that activity. The activities will be scrollable. In the app menu, the user will see a user profile icon, friends list icon, a '+' icon for creating a new activity (this one must be on the centre and must be the most highlighted) and an icon for seeing current activities that he enrolled in. Also on the top menu it will have emojis buttons that will act like filters. For example: Emoji for tennis: when clicked it will list only the tennis activities available. When clicked again it will cancel the filter. 2nd example: beers emojis: will list only the drinks activities avaialble, you get the idea. 

3. Analytics: Implement analytics instrumentation from the beggining. We will have analytics events for any user action: click button, activity shown, service user interaction: user logged in successfully, user created activity successfully:
The events naming pattern will be: 
3.1 For when activities are rendered:
Hang:${activity_title}:OnLoad - no duplications
3.2 For user action:
Hang:${button_name}:Clicked - for button clicks
Hang:${input_name}:Typing - for input typing (one event only for typing into an input)

4. Localization: Create from now .json files for supporting text localization. Start with en_US.json only for now and put all the text showed up in the app in it. Create a readable and clean structure in the file. For example, if i need the placeholder for inputting the activity title i will get it from en_US.json file from "activity.placeholder.title"

5. Create from now README for setting up the application and guide for running it


6. Costs of the app: Think about the costs also, choose a rentable technology for analytics events, think about how we will deploy the app, i want to make it available for both google play and app store, think about potential ab tests runnings in the future (what to use here - price smart), Think about integrating an AI to build user profiles and tendencies and recommend users activities that are most likely to join to based on their profile, not for now but for the future.

Implement also the backend part of the app. Think of most reliable way for database and other things needed, but start with the frontend.


After you read the entire description start building a plan for implementing all of this and start with the setup for flutter and installing all the necessary dependencies first, then build a small part of it just to run and see how it looks, then we will continue, also install something for testing for IOS or Android, wahtever is more reliable.