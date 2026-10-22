[RES-101] Fix Search Race Condition
Root cause:
The issue occurs because the input field's onChange event triggers an API call to search for data. Since onChange captures every single keystroke from the user, typing rapidly continuous input causes a race condition between API requests. To resolve this, a combined approach was implemented using Debounce (delay mechanism) and a Sequence check to ensure only the latest API request is processed.

Why this solution is effective:
The Debounce technique adds a slight delay to avoid firing frequent API calls to the backend, which reduces unnecessary API usage and minimizes the load on the server and network. Meanwhile, the Sequence check acts as a safeguard in case an API response takes too long to return, preventing outdated requests from overriding newer data.

Alternatives considered and rejected:
Making it so the user has to finish writing or typing before sending a call to the API. This method is not very good because it results in poor UX performance, whereas it should ideally show results as typed, whether it is the first character, second character, or before typing is completed.

Edge cases considered:
Handling the immediate text deletion when the user deletes that text in order to type anew.

[RES-102] Fix My Orders Crash
Root Cause:
The issue occurs because background operations continue running even after the user navigates away from the screen. Since the timer is not stopped upon exiting, it keeps executing in the background and attempts to trigger updates on a destroyed widget, resulting in a setState() called after dispose() error.

Why this solution is effective:
Canceling the timer within the dispose() method ensures that background tasks are properly terminated when the screen is closed. This prevents unnecessary resource usage, stops outdated operations from running, and cleanly resolves the lifecycle-related error.

Alternatives considered and rejected:
Using if (mounted) as part of the condition to solve this issue; however, this only hides the symptom where the error occurs rather than fixing the root cause that triggers dispose().

Edge cases considered:
Pausing the timer in pickup_countdown.dart temporarily in the background and having it resume when the user returns. We determined that even if it were stopped and the user returned later, it wouldn't have any noticeable effect on the user, and it carries a higher risk of destabilizing the system.

[RES-103] Fix send too many request
Root Cause:
The issue was caused by using an undisposed ever listener. Whenever the cart changed, it repeatedly triggered API calls for every deal previously viewed, even after those screens were closed. The controller should be properly disposed of when navigating away from the screen.

Why this solution is effective:
This approach prevents repetitive API calls for closed screens and ensures that only the current, active deal screen fetches the latest stock availability.

Alternatives considered and rejected:
Using debounce to delay the API calls. However, we determined that delaying it wouldn't help, would introduce latency that harms the app's UX responsiveness, and fails to address the root cause originating from the undisposed listener.

Edge cases considered:
Handling background cart synchronization to simultaneously calculate prices, time, or remaining quantities in the background.