/** <title>NSNib</title>
   
   <abstract>
   This class serves as a container for a nib file.  It's possible 
   to load a nib file from a URL or from a bundle.   Using this 
   class the nib file can now be "preloaded" and instantiated 
   multiple times when/if needed.  Also, since it's possible to 
   initialize this class using a NSURL it's possible to load 
   nib files from remote locations. 
   <br/>
   This class uses: NSNibOwner and NSNibTopLevelObjects to allow
   the caller to specify the owner of the nib during instantiation
   and receive an array containing the top level objects of the nib
   file.
   </abstract>

   Copyright (C) 2004 Free Software Foundation, Inc.

   Author: Gregory John Casamento <greg_casamento@yahoo.com>
   Date: 2004
   
   This file is part of the GNUstep GUI Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/> or write to the 
   Free Software Foundation, 51 Franklin Street, Fifth Floor, 
   Boston, MA 02110-1301, USA.
*/ 

#include <AppKit/NSNib.h>
#include <AppKit/NSNibLoading.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>
#include <Foundation/NSBundle.h>
#include <Foundation/NSURL.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSArchiver.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSException.h>

#include "GNUstepGUI/GSModelLoaderFactory.h"
#include "GNUstepGUI/GSGormLoading.h"
#include "GNUstepGUI/IMLoading.h"

@implementation NSNib

// private method to read in the data...
- (void) _readNibData: (NSString *)fileName
{
  NSDebugLog(@"Loading model `%@'...\n", fileName);
  NS_DURING
    {
      NSString *newFileName = [GSModelLoaderFactory supportedModelFileAtPath: fileName];
      ASSIGN(_nibData, [NSData dataWithContentsOfFile: newFileName]);
      ASSIGN(_loader, [GSModelLoaderFactory modelLoaderForFileName: newFileName]);
      NSDebugLog(@"Loaded data from %@...",newFileName);
    }
  NS_HANDLER
    {
      NSLog(@"Exception occured while loading model: %@",[localException reason]);
    }
  NS_ENDHANDLER
}

- (NSDictionary *) _copyTable: (NSDictionary *)dict
{
  NSMutableDictionary *ctx = nil;

  if (dict != nil)
    {
      id obj = nil;

      // copy the dictionary...
      ctx = [NSMutableDictionary dictionaryWithDictionary: dict];

      // remove and set the owner...
      obj = [ctx objectForKey: @"NSNibOwner"];
      if (obj != nil)
	{
	  [ctx removeObjectForKey: @"NSNibOwner"];
	  [ctx setObject: obj forKey: @"NSOwner"];
	}

      // Remove and set the top level objects...
      obj = [ctx objectForKey: @"NSNibTopLevelObjects"];
      if (obj != nil)
	{
	  [ctx removeObjectForKey: @"NSNibTopLevelObjects"];
	  [ctx setObject: obj forKey: @"NSTopLevelObjects"];
	}
    }

  return ctx;
}

// Public methods...

/**
 * Load the NSNib object from the specified URL.  This location can be
 * any type of resource capable of being pointed to by the NSURL object.
 * A file in the local file system or a file on an ftp site.
 */
- (id)initWithContentsOfURL: (NSURL *)nibFileURL
{
  if ((self = [super init]) != nil)
    {
      // load the nib data into memory...
      _nibData = [NSData dataWithContentsOfURL: nibFileURL];
      ASSIGN(_url, nibFileURL);
    }
  return self;
}

/**
 * Load the nib indicated by <code>nibNamed</code>.  If the <code>bundle</code>
 * argument is <code>nil</code>, then the main bundle is used to resolve 
 * the path, otherwise the bundle which is supplied will be used.
 */
- (id)initWithNibNamed: (NSString *)nibNamed bundle: (NSBundle *)bundle
{
  if ((self = [super init]) != nil)
    {
      NSString *fileName = nil;

      if (bundle == nil)
	{
	  bundle = [NSBundle mainBundle];
	}

      // initialize the bundle...
      fileName = [bundle pathForNibResource: nibNamed];

      // load the nib data into memory...
      [self _readNibData: fileName];
    }
  return self;
}

/**
 * This is a GNUstep specific method.  This method is used when the caller 
 * wants the objects instantiated in the nib to be stored in the given 
 * <code>zone</code>.
 */
- (BOOL)instantiateNibWithExternalNameTable: (NSDictionary *)externalNameTable
				   withZone: (NSZone *)zone
{
  return [_loader loadModelData: _nibData 
		  externalNameTable: externalNameTable
		  withZone: zone];
}

/**
 * This method instantiates the nib file.  The externalNameTable dictionary
 * accepts the NSNibOwner and NSNibTopLevelObjects entries described earlier.
 * It is recommended, for subclasses whose purpose is to change the behaviour 
 * of nib loading, to override this method.
 */
- (BOOL)instantiateNibWithExternalNameTable: (NSDictionary *)externalNameTable
{
  return [self instantiateNibWithExternalNameTable: externalNameTable
	       withZone: NSDefaultMallocZone()];
}

/**
 * This method instantiates the nib file.  It utilizes the 
 * instantiateNibWithExternalNameTable: method to, in a convenient way, 
 * allow the user to specify both keys accepted by the
 * nib loading process.
 */
- (BOOL)instantiateNibWithOwner: (id)owner topLevelObjects: (NSArray **)topLevelObjects
{
  NSMutableDictionary *externalNameTable = [NSMutableDictionary dictionary];

  // add the necessary things to the table...
  [externalNameTable setObject: owner forKey: @"NSNibOwner"];

  if (topLevelObjects != 0)
    {
      *topLevelObjects = [NSMutableArray array];
      [externalNameTable setObject: *topLevelObjects forKey: @"NSNibTopLevelObjects"];
    }

  return [self instantiateNibWithExternalNameTable: externalNameTable]; 
}

- (id) initWithCoder: (NSCoder *)coder
{
  if ((self = [super init]) != nil)
    {
      //
      // NOTE: This is okay, since the only encodings which will ever be built into
      //       the gui library are nib and gorm.  GModel only supports certain
      //       objects and is going to be deprecated in the future.  There just so
      //       happens to be a one to one correspondence here.
      //
      if ([coder allowsKeyedCoding])
	{
	  // TODO_NIB: Need to verify this key...
	  ASSIGN(_nibData, [coder decodeObjectForKey: @"NSData"]);
	  ASSIGN(_loader, [GSModelLoaderFactory modelLoaderForFileType: @"nib"]);
	}
      else
	{
	  // this is sort of a kludge...
	  [coder decodeValueOfObjCType: @encode(id)
		 at: &_nibData];
	  ASSIGN(_loader, [GSModelLoaderFactory modelLoaderForFileType: @"gorm"]);
	}
    }
  return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
  if ([coder allowsKeyedCoding])
    {
      // TODO_NIB: Need to verify this key...
      [coder encodeObject: _nibData 
	     forKey: @"NSData"];      
    }
  else
    {
      [coder encodeValueOfObjCType: @encode(id)
	     at: &_nibData];
    }
}

- (void) dealloc
{
  RELEASE(_nibData);
  RELEASE(_loader);
  TEST_RELEASE(_url);
  [super dealloc];
}

@end
