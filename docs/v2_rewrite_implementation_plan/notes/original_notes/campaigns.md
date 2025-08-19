# Campaign Management Pain Points

OK, the next set of pain points involve Campaigns. I'll describe my vision for the UX and you help me figure out the necessary API parts of the solution.

- We need the ability to reorder attacks in different ways, rather than them being by creation time or automatically by estimated complexity.

    - In the campaign view there will be a clearly understandable toolbar with a button to add an attack. That will pop the attack editor in a modal and add an attack to the end of the list.
    - There should be an option to have a menu pop out on an attack (right click or a little menu button) and that menu should have items such as "Remove", "Move Up", "Move Down", "Move To Top", "Move To Bottom", "Duplicate", and "Edit". Not in that order, though. They should be logically grouped.
    - The campaign view should show a list of attacks as a table-like view. the table should have columns for "Attack Type" (with a nice meaninful name), "Length" (if there's a character restriction such as 1-8 characters or just a blank for unlimited), "Settings" (Non-hashcat-nerd-friendly sentence describing the attack settings, clickable to open the editor modal, blank if a default like a dictionary attack with no special settings), "Passwords to Check" (estimated keyspace), "Complexity" (shown graphically 1-5 with stars or dots or something), "Comments" (user provided description truncated to visible space)
    - On the toolbar should also be a button to sort by duration/complexity. There should also be a group of buttons that enables a checkbox that lets you check individual attacks with a delete button, as well as a check all button. And then there should be a start/stop button and it should default to stop while you're editing it. When you're done, you hit the start button and it it just makes the campaign available to be tasked to the agents.
