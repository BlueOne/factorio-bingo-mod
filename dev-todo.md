
Dev-TODO
--------

Board Generation
* Design proper board generation. 
* Redesign difficulty balancing

Tasks
* More Task Types
    - Build restriction tasks e.g. build at most one offshore pump. Enforced by mod, with checkbox to remove enforcement and mark task as failed, enabled by default. Should allow multiple restrictions in one task. In particular: Do not build any of type x. 
    - Time limit tasks. "Research steel axe before 25 minutes"
    - Consider a model for subtasks / composite tasks. Ideally this would make tasks like "produce 5k iron plates before 20 minutes" or "build at most one type of inserter" easier, but needs to be well designed, maybe easier to code by hand in the few cases we want
* May need a better interface between board and tasks. Cannot currently reset tasks (e.g. to roll back erroneous completion of task)
* More Tasks. 

UI
* Make everything prettier i.e. work on styles

Spectator Tools

Game Rules / Setup
* Find a convenient way to enter settings such as board generation settings or recipe / technology state. Options appear to be mod settings, ingame menu or code. 


Control
* Chat cmds. for resetting / disabling tasks, rolling back a victory (need to make changes to Board / Task interface) and to start board for a player.

Meta
* Logo / Icon for the mod?
* Move this to git issues