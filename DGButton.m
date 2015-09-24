//
//  DGButton.m
//  DGButton
//
//  Created by Daniel Cohen Gindi on 1/24/13.
//  Copyright (c) 2013 danielgindi@gmail.com. All rights reserved.
//
//  https://github.com/danielgindi/DGButton
//
//  The MIT License (MIT)
//  
//  Copyright (c) 2014 Daniel Cohen Gindi (danielgindi@gmail.com)
//  
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//  
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE. 
//  

#import "DGButton.h"

typedef struct {
    BOOL rtl;
    BOOL imageOnTheRight;
    UIControlContentHorizontalAlignment contentHorizontalAlignment;
    UIControlContentVerticalAlignment contentVerticalAlignment;
    UIEdgeInsets contentEdgeInsets;
    UIEdgeInsets imageEdgeInsets;
    UIEdgeInsets titleEdgeInsets;
    CGRect bounds;
} PresentationState;

static inline BOOL presentationStateEqualToPresentationState(PresentationState state1, PresentationState state2)
{
    if (state1.rtl != state2.rtl) return NO;
    if (state1.imageOnTheRight != state2.imageOnTheRight) return NO;
    if (state1.contentHorizontalAlignment != state2.contentHorizontalAlignment) return NO;
    if (state1.contentVerticalAlignment != state2.contentVerticalAlignment) return NO;
    if (!UIEdgeInsetsEqualToEdgeInsets(state1.contentEdgeInsets, state2.contentEdgeInsets)) return NO;
    if (!UIEdgeInsetsEqualToEdgeInsets(state1.imageEdgeInsets, state2.imageEdgeInsets)) return NO;
    if (!UIEdgeInsetsEqualToEdgeInsets(state1.titleEdgeInsets, state2.titleEdgeInsets)) return NO;
    if (!CGRectEqualToRect(state1.bounds, state2.bounds)) return NO;
    return YES;
}

@implementation DGButton
{
    UIColor *_originalBackgroundColor;
    BOOL _isBackgroundColorSwitched;
    
    UIFont *_originalTitleLabelFont;
    BOOL _isTitleLabelFontSwitched;
    
    BOOL _hasSemanticDirection;
    
    PresentationState _lastPresentationState;
    UIImage *_lastPresentationImage;
    NSString *_lastPresentationTitle;
    CGRect _lastContentRect;
    CGRect _lastImageRect;
    CGRect _lastTitleRect;
    
    // This one is for allowing the UIButtonLabel to be created without intefering with its process, causing weird bugs...
    BOOL _didCreateTitleLabel;
}

- (void)initialize_DGButton
{
    _respondsToRtl = YES;
    _imageOnOppositeDirection = NO;
    
    _didCreateTitleLabel = NO;
    
    _hasSemanticDirection = ([[[UIDevice currentDevice] systemVersion] compare:@"9.0" options:NSNumericSearch] != NSOrderedAscending);
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        [self initialize_DGButton];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self initialize_DGButton];
    }
    return self;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    if (_isBackgroundColorSwitched)
    {
        _originalBackgroundColor = backgroundColor;
    }
    else
    {
        [super setBackgroundColor:backgroundColor];
    }
}

- (void)setHighlightedBackgroundColor:(UIColor *)highlightedBackgroundColor
{
    _highlightedBackgroundColor = highlightedBackgroundColor;
    
    [self _buttonModesUpdated];
}

- (void)setDisabledBackgroundColor:(UIColor *)disabledBackgroundColor
{
    _disabledBackgroundColor = disabledBackgroundColor;
    
    [self _buttonModesUpdated];
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    
    [self _buttonModesUpdated];
}

- (void)setEnabled:(BOOL)enabled
{
    [super setEnabled:enabled];
    
    [self _buttonModesUpdated];
}

- (void)setImageOnOppositeDirection:(BOOL)imageOnOppositeDirection
{
    _imageOnOppositeDirection = imageOnOppositeDirection;
    [self setNeedsLayout];
}

- (void)setRespondsToRtl:(BOOL)respondsToRtl
{
    _respondsToRtl = respondsToRtl;
    [self setNeedsLayout];
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    
    [self _buttonModesUpdated];
}

- (void)calculateRectsIfNeededForBounds:(CGRect)bounds
{
    UIUserInterfaceLayoutDirection userInterfaceLayoutDirection =
    _hasSemanticDirection ?
    [UIButton userInterfaceLayoutDirectionForSemanticContentAttribute:self.semanticContentAttribute] :
    (_respondsToRtl ? UIApplication.sharedApplication.userInterfaceLayoutDirection : UIUserInterfaceLayoutDirectionLeftToRight);
    
    PresentationState state;
    state.rtl = userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
    state.imageOnTheRight = state.rtl != _imageOnOppositeDirection;
    state.bounds = bounds;
    state.contentHorizontalAlignment = self.contentHorizontalAlignment;
    state.contentVerticalAlignment = self.contentVerticalAlignment;
    state.contentEdgeInsets = self.contentEdgeInsets;
    state.imageEdgeInsets = self.imageEdgeInsets;
    state.titleEdgeInsets = self.titleEdgeInsets;
    
    if (presentationStateEqualToPresentationState(state, _lastPresentationState) && _lastPresentationImage == self.currentImage && _lastPresentationTitle == self.currentTitle)
    {
        return;
    }
    
    // Save last state here, to prevent recursive calls when "getting" titleLabel
    _lastPresentationState = state;
    _lastPresentationImage = self.currentImage;
    _lastPresentationTitle = self.currentTitle;
    
    // Determine contentRect
    CGRect contentRect = bounds;
    contentRect.origin.x += state.contentEdgeInsets.left;
    contentRect.origin.y += state.contentEdgeInsets.top;
    contentRect.size.width -= state.contentEdgeInsets.left + state.contentEdgeInsets.right;
    contentRect.size.height -= state.contentEdgeInsets.top + state.contentEdgeInsets.bottom;
    contentRect.size.width = MAX(contentRect.size.width, 0.f);
    contentRect.size.height = MAX(contentRect.size.height, 0.f);
    
    CGRect imageRect, titleRect;
    CGSize fitInSize;
    
    // Determine available area for image
    fitInSize = contentRect.size;
    fitInSize.width -= state.imageEdgeInsets.left + state.imageEdgeInsets.right;
    fitInSize.height -= state.imageEdgeInsets.top + state.imageEdgeInsets.bottom;
    fitInSize.width = MAX(fitInSize.width, 0.f);
    fitInSize.height = MAX(fitInSize.height, 0.f);
    imageRect.size = _lastPresentationImage.size;
    if (imageRect.size.width > fitInSize.width || imageRect.size.height > fitInSize.height)
    {
        CGFloat scaleW = fitInSize.width / imageRect.size.width;
        CGFloat scaleH = fitInSize.height / imageRect.size.height;
        CGFloat scale = MIN(scaleW, scaleH);
        imageRect.size.width *= scale;
        imageRect.size.height *= scale;
    }
    
    // Determine available area for title
    fitInSize = CGSizeMake(contentRect.size.width - imageRect.size.width - state.imageEdgeInsets.left - state.imageEdgeInsets.right, contentRect.size.height - state.imageEdgeInsets.top - state.imageEdgeInsets.bottom);
    fitInSize.width = MAX(fitInSize.width, 0.f);
    fitInSize.height = MAX(fitInSize.height, 0.f);
    
    //[self updateSizingTitleLabel];
    
    titleRect.size = [self.titleLabel sizeThatFits:fitInSize];
    
    // Calculate vertical placement of title and image
    switch (state.contentVerticalAlignment)
    {
        case UIControlContentVerticalAlignmentTop:
            imageRect.origin.y = contentRect.origin.y + state.imageEdgeInsets.top;
            titleRect.origin.y = contentRect.origin.y + state.titleEdgeInsets.top;
            break;
            
        case UIControlContentVerticalAlignmentBottom:
            imageRect.origin.y = contentRect.origin.y + contentRect.size.height - imageRect.size.height - state.imageEdgeInsets.bottom;
            titleRect.origin.y = contentRect.origin.y + contentRect.size.height - titleRect.size.height - state.titleEdgeInsets.bottom;
            break;
            
        case UIControlContentVerticalAlignmentCenter:
            imageRect.origin.y = contentRect.origin.y + (contentRect.size.height - imageRect.size.height) / 2.f + state.imageEdgeInsets.top - state.imageEdgeInsets.bottom;
            titleRect.origin.y = contentRect.origin.y + (contentRect.size.height - titleRect.size.height) / 2.f + state.titleEdgeInsets.top - state.titleEdgeInsets.bottom;
            break;
            
        case UIControlContentVerticalAlignmentFill:
            imageRect.origin.y = contentRect.origin.y + state.imageEdgeInsets.top + state.imageEdgeInsets.bottom;
            imageRect.size.height = contentRect.size.height - state.imageEdgeInsets.top - state.imageEdgeInsets.bottom;
            titleRect.origin.y = contentRect.origin.y + state.titleEdgeInsets.top + state.titleEdgeInsets.bottom;
            titleRect.size.height = contentRect.size.height - state.titleEdgeInsets.top - state.titleEdgeInsets.bottom;
            break;
    }
    
    // Calculate horizontal placement of title and image
    switch (state.contentHorizontalAlignment)
    {
        case UIControlContentHorizontalAlignmentLeft:
            if (_imageOnOppositeDirection)
            {
                titleRect.origin.x = contentRect.origin.x + state.titleEdgeInsets.left;
                imageRect.origin.x = contentRect.origin.x + titleRect.size.width + state.imageEdgeInsets.left;
            }
            else
            {
                imageRect.origin.x = contentRect.origin.x + state.imageEdgeInsets.left;
                titleRect.origin.x = contentRect.origin.x + imageRect.size.width +  state.titleEdgeInsets.left;
            }
            break;
            
        case UIControlContentHorizontalAlignmentRight:
            if (_imageOnOppositeDirection)
            {
                imageRect.origin.x = contentRect.origin.x + contentRect.size.width - imageRect.size.width - state.imageEdgeInsets.right;
                titleRect.origin.x = contentRect.origin.x + contentRect.size.width - imageRect.size.width - titleRect.size.width - state.titleEdgeInsets.right;
            }
            else
            {
                titleRect.origin.x = contentRect.origin.x + contentRect.size.width - titleRect.size.width - state.titleEdgeInsets.right;
                imageRect.origin.x = contentRect.origin.x + contentRect.size.width - titleRect.size.width - imageRect.size.width - state.imageEdgeInsets.right;
            }
            break;
            
        case UIControlContentHorizontalAlignmentCenter:
        {
            CGFloat totalWidth = imageRect.size.width + titleRect.size.width;
            CGFloat x = contentRect.origin.x + (contentRect.size.width - totalWidth) / 2.f;
            
            if (_imageOnOppositeDirection)
            {
                titleRect.origin.x = x + state.titleEdgeInsets.left - state.titleEdgeInsets.right;
                imageRect.origin.x = x + titleRect.size.width + state.imageEdgeInsets.left - state.imageEdgeInsets.right;
            }
            else
            {
                imageRect.origin.x = x + state.imageEdgeInsets.left - state.imageEdgeInsets.right;
                titleRect.origin.x = x + imageRect.size.width + state.titleEdgeInsets.left - state.titleEdgeInsets.right;
            }
        }
            break;
            
        case UIControlContentHorizontalAlignmentFill:
            imageRect.origin.x = contentRect.origin.x + state.imageEdgeInsets.left + state.imageEdgeInsets.right;
            imageRect.size.width = contentRect.size.width - state.imageEdgeInsets.left - state.imageEdgeInsets.right;
            titleRect.origin.x = contentRect.origin.x + state.titleEdgeInsets.left + state.titleEdgeInsets.right;
            titleRect.size.width = contentRect.size.width - state.titleEdgeInsets.left - state.titleEdgeInsets.right;
            break;
    }
    
    // Flip rects for RTL
    if (state.rtl)
    {
        imageRect.origin.x = contentRect.size.width - (imageRect.origin.x - contentRect.origin.x) - imageRect.size.width + contentRect.origin.x;
        titleRect.origin.x = contentRect.size.width - (titleRect.origin.x - contentRect.origin.x) - titleRect.size.width + contentRect.origin.x;
    }
    
    // Save calculations for the next time
    _lastContentRect = contentRect;
    _lastImageRect = imageRect;
    _lastTitleRect = titleRect;
}

- (CGRect)contentRectForBounds:(CGRect)bounds
{
    if (!_didCreateTitleLabel)
    {
        _didCreateTitleLabel = YES;
        return [super contentRectForBounds:bounds];
    }
    
    [self calculateRectsIfNeededForBounds:bounds];
    
    return _lastContentRect;
}

- (CGRect)imageRectForContentRect:(CGRect)contentRect
{
    if (!_didCreateTitleLabel)
    {
        return [super imageRectForContentRect:contentRect];
    }
    
    return _lastImageRect;
}

- (CGRect)titleRectForContentRect:(CGRect)contentRect
{
    if (!_didCreateTitleLabel)
    {
        return [super titleRectForContentRect:contentRect];
    }
    
    return _lastTitleRect;
}

- (CGSize)sizeThatFits:(CGSize)size
{
    if (!_didCreateTitleLabel)
    {
        return [super sizeThatFits:size];
    }
    
    CGSize imageSize = self.currentImage.size;
    CGSize titleSize = [self.titleLabel sizeThatFits:size];
    CGSize newSize;
    
    if (self.contentHorizontalAlignment == UIControlContentHorizontalAlignmentFill)
    {
        newSize.width = size.width;
    }
    else
    {
        newSize.width = imageSize.width + titleSize.width;
    }
    
    if (self.contentVerticalAlignment == UIControlContentVerticalAlignmentFill)
    {
        newSize.height = size.height;
    }
    else
    {
        newSize.width = MAX(imageSize.height, titleSize.height);
    }
    
    newSize.width = MIN(newSize.width, size.width);
    newSize.height = MIN(newSize.height, size.height);
    
    return newSize;
}

- (void)_buttonModesUpdated
{
    if (!_isBackgroundColorSwitched)
    {
        _originalBackgroundColor = self.backgroundColor;
    }
    if (!_isTitleLabelFontSwitched)
    {
        _originalTitleLabelFont = self.titleLabel.font;
    }
    
    if (self.enabled)
    {
        if (self.highlighted && _highlightedBackgroundColor)
        {
            _isBackgroundColorSwitched = YES;
            super.backgroundColor = _highlightedBackgroundColor;
        }
        else
        {
            _isBackgroundColorSwitched = NO;
            super.backgroundColor = _originalBackgroundColor;
        }
    }
    else
    {
        if (_disabledBackgroundColor)
        {
            _isBackgroundColorSwitched = YES;
            super.backgroundColor = _disabledBackgroundColor;
        }
        else
        {
            _isBackgroundColorSwitched = NO;
            super.backgroundColor = _originalBackgroundColor;
        }
    }
    
    if (self.selected && _selectedTitleLabelFont)
    {
        _isTitleLabelFontSwitched = YES;
        self.titleLabel.font = _selectedTitleLabelFont;
    }
    else
    {
        _isTitleLabelFontSwitched = NO;
        self.titleLabel.font = _originalTitleLabelFont;
    }
}

@end
