# graffiti

A Nimble git tagger, it creates tags for your nimble versions so you do not need to. 

Usage is simple: 

```sh
# install
nimble install https://github.com/beef331/graffiti.git
## create tags
graffiti some_project/some_project.nimble
```

```sh
# It also can manually bump a project.
graffiti ./some_project.nimble 0.3.2 
```

If the first commit of the repository includes the nimble file the very first version will not be automatically tagged.

## Testimonials

@elcritch said "I give this utility 2 thumbs up. It saved me from typing 178 characters just today! But now the two users who use my libs can rest well knowing my repos are now tagged for their Nimble convenience."

