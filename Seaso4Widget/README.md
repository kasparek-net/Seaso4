# Seaso4 Widget Extension

This folder contains the home screen widget. To use it:

## 1. Add the Widget Extension target in Xcode

1. **File → New → Target**
2. Choose **Widget Extension**
3. Name it e.g. **Seaso4Widget**
4. Uncheck **Include Configuration App Intent** (optional; we use app settings instead)
5. Finish. Xcode will create a new folder and a default widget file.

## 2. Use this widget code

- **Option A:** Delete the generated widget Swift file in the new target, then add this folder’s **Seaso4Widget.swift** to the widget target (drag the file into the project and check the widget target under Target Membership).
- **Option B:** Replace the contents of the generated widget file with the contents of **Seaso4Widget.swift**, then you can remove this folder if you prefer a single widget file.

## 3. App Group (required)

So the widget can read the same settings as the app (astronomical/calendar, which season to show):

1. Select the **main app target** → **Signing & Capabilities** → **+ Capability** → **App Groups** → add: `group.jk.Seaso4`
2. Select the **widget extension target** → **Signing & Capabilities** → **+ Capability** → **App Groups** → add the same: `group.jk.Seaso4`

If the bundle identifier is not `jk.Seaso4`, use an App Group ID that matches (e.g. `group.$(YOUR_BUNDLE_ID)`).

### If it works in Simulator but not on a real device

On a real device, App Groups are enforced strictly. Check:

1. **Apple Developer Portal** → **Identifiers**  
   - Open the **main app** App ID (e.g. `jk.Seaso4`) → **App Groups** must be enabled and the group `group.jk.Seaso4` must be assigned.  
   - Open the **widget extension** App ID (e.g. `jk.Seaso4.Seaso4Widget`) → **App Groups** must be enabled and the **same** group `group.jk.Seaso4` must be assigned.

2. **App Groups** → Create the group `group.jk.Seaso4` if it does not exist, and assign it to both App IDs above.

3. In **Xcode**: for both the app and the widget target, **Signing & Capabilities** → **App Groups** → ensure `group.jk.Seaso4` is checked for **Debug and Release**.

4. After changing anything in the portal, regenerate/download provisioning profiles (e.g. Xcode **Signing & Capabilities** → switch team or re-check "Automatically manage signing") and do a clean build on the device.

## 4. "Show Notification Center Widget timed out" (Xcode error)

If you see **SendProcessControlEvent Code=32 "Show Notification Center Widget timed out"** in the console, Xcode is trying to show the widget when running the **widget extension** scheme and the request is timing out. This is a known Xcode/simulator quirk, not an app bug.

**Fix:** Always run the **main app** scheme (**Seaso4**), not **Seaso4Widget**. To test the widget: run the app → on the simulator or device, add the widget from the home screen (long press → Add Widget → choose Seaso4). The widget will then work and update normally.

## 5. Supported widget sizes

- **Small** (1 tile): emoji, season name, progress ring, percentage, definition label
- **Medium** (2 tiles): ring + name, percentage, days elapsed / days left
- **Large** (3 tiles): full layout with ring, percentage, days elapsed / days left

The widget respects the system **Light/Dark** appearance. Settings **Main season display** (Astronomical/Calendar) and **Widget displays** (Current season or a fixed season) are shared with the app via the App Group.
