Salesforce Chatter Bot for Feeds
================================

Overview
--------

Chatter Bot for Feeds enables you to post Chatter messages authored by any user. The best part is that you can automate these messages with Process Builder or Flow!
Although there are many ways to post Chatter messages in Salesforce using Process Builder, Flow, Apex, or API, no one approach satisfied all of my requirements:

1. Must be easy to use and launchable by Process Builder or Flow (declarative)
2. Must support setting the author to someone other than the running user
3. Must support rich-text
4. Must support @ mentions

To learn more about my design decisions, please [read my blog post](https://douglascayers.com) introducing Chatter Bot for Feeds.


Installation & Getting Started
------------------------------

*Video tutorial coming soon!*

1. Deploy [Chatter Bot for Groups](https://github.com/DouglasCAyers/salesforce-chatter-bot-groups#overview) and follow its **Getting Started** steps. *(the examples depend on this)*
2. Deploy [Chatter Bot for Feeds](https://githubsfdeploy.herokuapp.com/).
3. In Setup, create an **Email Service** using apex class `ChatterBotPostMessageEmailHandler` and an **Email Address**. Set the **Context User** to an **administrator** user.
4. Assign the **Chatter Bot Feeds Admin** permission set to the **Context User** to allow setting author for new Chatter posts.
5. Create a [Chatter Free](https://help.salesforce.com/articleView?id=users_license_types_chatter.htm&type=0&language=en_US) user and set their **email address** to be the same as the Email Service Address from Step 3.
6. Create a default organization default value for the **Chatter Bot Feeds Setting** custom setting and copy into the **Email Service Address User ID** field the ID of the Chatter Free user from Step 5.


FAQ
===

Why do I get error "The object named Chatter_Bot_Group_Member__c can't be found." during deployment?
----------------------------------------------------------------------------------------------------

The example Process Builder included in **Chatter Bot for Feeds** is designed for the use case when users join a group. That capability is only provided through **Chatter Bot for Groups**.
See also question [Can Chatter Bot for Feeds be used without Chatter Bot for Groups?](#can-chatter-bot-for-feeds-be-used-without-chatter-bot-for-groups).


Can Chatter Bot for Feeds be used without Chatter Bot for Groups?
-----------------------------------------------------------------

In practice, yes. For deployment, not at this time. The example Process Builder included in **Chatter Bot for Feeds** is designed for the use case when users join a group. That capability is only provided through **Chatter Bot for Groups**.
Once deployed, you can begin automating Chatter posts for any reason you want using Process Builder or Flow. The dependency on **Chatter Bot for Groups** is just for the example Process Builder.


Why do I need an Email Service to make Chatter posts?
-----------------------------------------------------

The Email Service is only so that we can get code to execute as an administrator and not the current user. Technically, you don't need it to post Chatter messages unless you have these three requirements:

1. You want to set the author to someone other than the running user
2. You want to post a rich-text message
3. You want to @ mention users or groups

To learn more about my design decisions, please [read my blog post](https://douglascayers.com) introducing Chatter Bot for Feeds.


Why is a Chatter Free user necessary for the Email Service?
-----------------------------------------------------------

Not for any technical reason to get this solution to work but rather to avoid using up any of your [org's daily email quota](https://developer.salesforce.com/docs/atlas.en-us.salesforce_app_limits_cheatsheet.meta/salesforce_app_limits_cheatsheet/salesforce_app_limits_platform_email.htm).
Apex can send a certain number of emails to external addresses each day, but an unlimited number of emails can be sent to internal users. Using a Chatter Free user for this purpose is a free and easy way around the Apex limitation.
