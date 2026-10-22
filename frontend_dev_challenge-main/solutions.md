[RES-101] Fix Search Race Condition
Root cause:
The issue occurs because the input field's onChange event triggers an API call to search for data. Since onChange captures every single keystroke from the user, typing rapidly continuous input causes a race condition between API requests. To resolve this, a combined approach was implemented using Debounce (delay mechanism) and a Sequence check to ensure only the latest API request is processed.

Why this solution is effective:
The Debounce technique adds a slight delay to avoid firing frequent API calls to the backend, which reduces unnecessary API usage and minimizes the load on the server and network. Meanwhile, the Sequence check acts as a safeguard in case an API response takes too long to return, preventing outdated requests from overriding newer data.

Alternatives considered and rejected:
Making it so the user has to finish writing or typing before sending a call to the API. This method is not very good because it results in poor UX performance, whereas it should ideally show results as typed, whether it is the first character, second character, or before typing is completed.

Edge cases considered:
Handling the immediate text deletion when the user deletes that text in order to type anew.

