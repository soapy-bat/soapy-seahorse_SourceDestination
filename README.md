# soapy-seahorse Source-Destination
The seahorse scripts provide tools for two multitrack workflows using REAPER:

## 1. Three-point and four-point source-destination editing
### Required
"Markers" and "Edit" scripts.
### How to use
- source gates are set using ```SetSrcIn``` and ```SetSrcOut```: Select an item (grouped items are possible as well), place the edit cursor inside the item. This will place flagged take markers at the cursor position (also while playing back).
- destination gate is set using ```SetDstIn```: This will create a flagged project marker at the cursor position.
- three-point edit: make sure to select the source item (that contains the source gates) and run the script. It will paste the area(s) between SRC_IN and SRC_OUT to the topmost lane at DST_IN.
### Notes
- The script ```Edit_3pointAssembly``` allows user customization by editing the ```user settings``` at the beginning of the file.
- The script assumes that source items be places on fixed item lanes and that the topmost lane will contain the comp.

## 2. Fade auditioning
### Required
"Fades" scripts.
### Functions
- ```AuditionOIn``` / ```AuditionOOut``` auditions the original material ("behind the fade") to the left or right of the fade.
- ```AuditionXFade``` auditions the crossfade.
- ```AuditionXIn``` / ```AuditionXOut``` auditions the left or right side of a fade while muting the other side.
### Notes
- The pre roll / post roll lengths are user customizable by editing the ```user settings``` section inside the respective scripts.
- Make sure to activate ```Offset overlapping media items vertically``` and ```Show / play only one lane``` when auditioning using ```AuditionOIn``` and ```AuditionOOut```. (This will be resolved at a later stage.)

# Important notice
- Many scripts require the file ```soapy-seahorse_Fades_Functions.lua``` in order to work.
- Development and documentation are in progress. Please report any issues with the provided functions.
- When editing in ripple edit mode, the [following scripts](https://github.com/soapy-bat/soapy-snail_LockSource) might be useful.

# Limitations
[see "Issues" on GitHub](https://github.com/soapy-bat/soapy-seahorse_SourceDestination/issues)

# Credits
- copyright 2024 the soapy zoo
