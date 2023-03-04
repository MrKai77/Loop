//
//  Loop-Bridging-Header.h
//  Loop
//
//  Created by Kai Azim on 2023-02-20.
//

#ifndef Loop_Bridging_Header_h
#define Loop_Bridging_Header_h

#include <CoreGraphics/CoreGraphics.h>

int _CGSDefaultConnection();
id CGSCopyManagedDisplaySpaces(int conn);
id CGSCopyActiveMenuBarDisplayIdentifier(int conn);

#endif /* Loop_Bridging_Header_h */
