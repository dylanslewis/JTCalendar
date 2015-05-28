//
//  JTCalendarDayView.m
//  JTCalendar
//
//  Created by Jonathan Tribouharet
//

#import "JTCalendarDayView.h"

#import "JTCircleView.h"


@interface JTCalendarDayView (){
    JTCircleView *circleView;
    UILabel *textLabel;
    JTCircleView *dotView;
    UILabel *monthLabel;
    UILabel *yearLabel;

    UIView *backgroundView;
    
    BOOL isSelected;
    BOOL isJustCreated;
    
    int cacheIsToday;
    NSString *cacheCurrentDateText;
}
@end

static NSString *kJTCalendarDaySelected = @"kJTCalendarDaySelected";

@implementation JTCalendarDayView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if(!self){
        return nil;
    }
    
    [self commonInit];
    
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if(!self){
        return nil;
    }
    
    [self commonInit];
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter]  removeObserver:self];
}

- (void)commonInit
{
    isSelected = NO;
    self.isOtherMonth = NO;
    isJustCreated = true;
    
    {
        backgroundView = [UIView new];
        [self addSubview:backgroundView];
    }
    
    {
        circleView = [JTCircleView new];
        [self addSubview:circleView];
    }
    
    {
        textLabel = [UILabel new];
        [self addSubview:textLabel];
    }
    
    {
        dotView = [JTCircleView new];
        [self addSubview:dotView];
        dotView.hidden = YES;
    }

    {
        monthLabel = [UILabel new];
        [self addSubview:monthLabel];
    }
    
    {
        yearLabel = [UILabel new];
        [self addSubview:yearLabel];
    }
    
    {
        UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTouch)];
        
        self.userInteractionEnabled = YES;
        [self addGestureRecognizer:gesture];
    }
    
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didDaySelected:) name:kJTCalendarDaySelected object:nil];
    }
}

- (void)layoutSubviews
{
    [self configureConstraintsForSubviews];
    
    // No need to call [super layoutSubviews]
}

// Avoid to calcul constraints (very expensive)
- (void)configureConstraintsForSubviews
{
    textLabel.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
    monthLabel.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height/3);
    yearLabel.frame = CGRectMake(0, 27, self.frame.size.width, self.frame.size.height/3);
    
    CGFloat circleEdgeSize = self.calendarManager.calendarAppearance.circleEdgeSize;

    CGFloat sizeDot = circleEdgeSize;
    
    sizeDot = sizeDot * self.calendarManager.calendarAppearance.dayDotRatio;
    
    sizeDot = roundf(sizeDot);
    
    circleView.frame = CGRectMake(0, 0, circleEdgeSize, circleEdgeSize);
    circleView.center = CGPointMake(self.frame.size.width / 2., self.frame.size.height / 2.);
    circleView.layer.cornerRadius = circleEdgeSize / 2.;
    
    dotView.frame = CGRectMake(0, 0, sizeDot, sizeDot);
    dotView.center = CGPointMake(self.frame.size.width / 2., (self.frame.size.height / 2.) + sizeDot * 2.5);
    dotView.layer.cornerRadius = sizeDot / 2.;
}

- (void)setDate:(NSDate *)date
{
    static NSDateFormatter *dateFormatter;
    if(!dateFormatter){
        dateFormatter = [NSDateFormatter new];
        dateFormatter.timeZone = self.calendarManager.calendarAppearance.calendar.timeZone;
        [dateFormatter setDateFormat:@"dd"];
    }
    
    self->_date = date;
    
    NSString *dateString = [dateFormatter stringFromDate:date];
    
    textLabel.text = dateString;

    if ([dateString isEqualToString:@"01"]) {
        NSDateFormatter *dateFormatterMonth = [NSDateFormatter new];
        dateFormatterMonth.timeZone = self.calendarManager.calendarAppearance.calendar.timeZone;
        [dateFormatterMonth setDateFormat:@"MMM"];
        
        monthLabel.text = [dateFormatterMonth stringFromDate:date].uppercaseString;
    } else {
        monthLabel.text = @"";
    }
    
    if ([self monthIndexForDate:date] == 1 && [dateString isEqualToString:@"01"]) {
        NSDateFormatter *dateFormatterYear = [NSDateFormatter new];
        dateFormatterYear.timeZone = self.calendarManager.calendarAppearance.calendar.timeZone;
        [dateFormatterYear setDateFormat:@"YYYY"];
        
        yearLabel.text = [dateFormatterYear stringFromDate:date];
    } else {
        yearLabel.text = @"";
    }
    
    cacheIsToday = -1;
    cacheCurrentDateText = nil;
    
    
    // FORCE setSelected TO GET CALLED, SHOULD DEAL WITH UI ISSUES
    
    [self reloadData];
}

- (void)didTouch
{
    if ([self isDateInTheFuture:self.date]) {
        if (self.calendarManager.endDate == nil) {
            if (self.date < self.calendarManager.startDate) {
                self.calendarManager.startDate = self.date;
            } else if (self.date > self.calendarManager.startDate) {
                self.calendarManager.endDate = self.date;
            }
        } else {
            if (self.date >= self.calendarManager.startDate && self.date <= self.calendarManager.endDate) {
                self.calendarManager.startDate = self.date;
            } else {
                self.calendarManager.startDate = self.date;
                self.calendarManager.endDate = nil;
            }
        }
        
        
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kJTCalendarDaySelected object:self.date];
        
        // SOMETIMES CRASHES HERE
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"updatedStartDate" object:self.calendarManager.startDate];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"updatedEndDate" object:self.calendarManager.endDate];

        [self.calendarManager.dataSource calendarDidDateSelected:self.calendarManager date:self.date];
        
        if(!self.isOtherMonth){
            return;
        }
        
        
        NSInteger currentMonthIndex = [self monthIndexForDate:self.date];
        NSInteger calendarMonthIndex = [self monthIndexForDate:self.calendarManager.currentDate];
        
        currentMonthIndex = currentMonthIndex % 12;
        
        if(currentMonthIndex == (calendarMonthIndex + 1) % 12){
            [self.calendarManager loadNextMonth];
        }
        else if(currentMonthIndex == (calendarMonthIndex + 12 - 1) % 12) {
            [self.calendarManager loadPreviousMonth];
        }
    }
}

- (BOOL)isDateInTheFuture:(NSDate *)inputDate {
    NSCalendar *myCalendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *dateComponentsCurrentCell = [myCalendar components:NSCalendarUnitMonth | NSCalendarUnitYear | NSCalendarUnitDay fromDate:inputDate];
    NSDateComponents *dateComponentsRealDate = [myCalendar components:NSCalendarUnitMonth | NSCalendarUnitYear | NSCalendarUnitDay fromDate:[NSDate date]];
    
    NSInteger currentCellMonth = dateComponentsCurrentCell.month;
    NSInteger currentCellYear = dateComponentsCurrentCell.year;
    NSInteger currentCellDay = dateComponentsCurrentCell.day;
    
    NSInteger currentRealMonth = dateComponentsRealDate.month;
    NSInteger currentRealYear = dateComponentsRealDate.year;
    NSInteger currentRealDay = dateComponentsRealDate.day;
    
    if ([inputDate compare:[NSDate date]] != NSOrderedAscending || (currentCellMonth == currentRealMonth && currentCellYear == currentRealYear && currentCellDay >= currentRealDay)) {
        return true;
    } else {
        return false;
    }
}

- (void)didDaySelected:(NSNotification *)notification
{
    if ([self isDateInTheFuture:self.date]) {
        if ([self isSameDate:self.calendarManager.startDate]) {
            [self setSelected:YES animated:YES];
        } else if ([self isSameDate:self.calendarManager.endDate]) {
            [self setSelected:YES animated:YES];
        } else {
            [self setSelected:NO animated:YES];
        }
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    if (self.date != nil) {
        NSLog(@"");
    }
    
        if(isSelected == selected){
            animated = NO;
        }
        
        isSelected = selected;
        
        circleView.transform = CGAffineTransformIdentity;
        CGAffineTransform tr = CGAffineTransformIdentity;
        CGFloat opacity = 1.;
        
        if(selected){
            if(!self.isOtherMonth){
                circleView.color = [self.calendarManager.calendarAppearance dayCircleColorSelected];
                textLabel.textColor = [self.calendarManager.calendarAppearance dayTextColorSelected];
                monthLabel.textColor = [self.calendarManager.calendarAppearance dayTextColorSelected];
                yearLabel.textColor = [self.calendarManager.calendarAppearance dayTextColorSelected];
                dotView.color = [self.calendarManager.calendarAppearance dayDotColorSelected];
            }
            else{
                circleView.color = [self.calendarManager.calendarAppearance dayCircleColorSelectedOtherMonth];
                textLabel.textColor = [self.calendarManager.calendarAppearance dayTextColorSelectedOtherMonth];
                monthLabel.textColor = [self.calendarManager.calendarAppearance dayTextColorSelectedOtherMonth];
                yearLabel.textColor = [self.calendarManager.calendarAppearance dayTextColorSelectedOtherMonth];
                dotView.color = [self.calendarManager.calendarAppearance dayDotColorSelectedOtherMonth];
            }
            
            circleView.transform = CGAffineTransformScale(CGAffineTransformIdentity, 0.1, 0.1);
            tr = CGAffineTransformIdentity;
        }
        else if([self isToday]){
            if(!self.isOtherMonth){
                circleView.color = [self.calendarManager.calendarAppearance dayCircleColorToday];
                textLabel.textColor = [self.calendarManager.calendarAppearance dayTextColorToday];
                monthLabel.textColor = [self.calendarManager.calendarAppearance dayTextColorToday];
                yearLabel.textColor = [self.calendarManager.calendarAppearance dayTextColorToday];
                dotView.color = [self.calendarManager.calendarAppearance dayDotColorToday];
            }
            else{
                circleView.color = [self.calendarManager.calendarAppearance dayCircleColorTodayOtherMonth];
                textLabel.textColor = [self.calendarManager.calendarAppearance dayTextColorTodayOtherMonth];
                monthLabel.textColor = [self.calendarManager.calendarAppearance dayTextColorTodayOtherMonth];
                yearLabel.textColor = [self.calendarManager.calendarAppearance dayTextColorTodayOtherMonth];
                dotView.color = [self.calendarManager.calendarAppearance dayDotColorTodayOtherMonth];
            }
        } else {
            if(!self.isOtherMonth){
                textLabel.textColor = [self.calendarManager.calendarAppearance dayTextColor];
                monthLabel.textColor = [self.calendarManager.calendarAppearance dayTextColor];
                yearLabel.textColor = [self.calendarManager.calendarAppearance dayTextColor];
                dotView.color = [self.calendarManager.calendarAppearance dayDotColor];
                
                if (self.date) {
                    NSCalendar *myCalendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
                    NSDateComponents *myComponents = [myCalendar components:NSCalendarUnitWeekday fromDate:self.date];
                    NSInteger weekDay = myComponents.weekday;
                    
                    if (weekDay == 7 || weekDay == 1) {
                        textLabel.textColor = [UIColor yellowColor];
                    }
                }
            }
            else {
                textLabel.textColor = [self.calendarManager.calendarAppearance dayTextColorOtherMonth];
                monthLabel.textColor = [self.calendarManager.calendarAppearance dayTextColorOtherMonth];
                yearLabel.textColor = [self.calendarManager.calendarAppearance dayTextColorOtherMonth];
                dotView.color = [self.calendarManager.calendarAppearance dayDotColorOtherMonth];
            }
            
            opacity = 0.;
        }
        
        if (self.date != nil) {
            BOOL didChange = false;

            CGFloat cellWidth = [[UIScreen mainScreen] bounds].size.width / 7;
            CGFloat circleEdgeSize = self.calendarManager.calendarAppearance.circleEdgeSize;
            CGFloat cellHeight = 300 / 7;
            
            if ([self isSameDate:self.calendarManager.startDate]) {
                if (backgroundView.backgroundColor != [self.calendarManager.calendarAppearance dayCircleColorSelected] ||
                    isJustCreated) {
                    backgroundView.backgroundColor = [self.calendarManager.calendarAppearance dayCircleColorSelected];
                    backgroundView.frame = CGRectMake(cellWidth/2, (cellHeight - circleEdgeSize)/2, cellWidth/2, circleEdgeSize);
                    didChange = true;
                }
            } else if ([self isSameDate:self.calendarManager.endDate]) {
                if (backgroundView.backgroundColor != [self.calendarManager.calendarAppearance dayCircleColorSelected] ||
                    isJustCreated) {
                    backgroundView.backgroundColor = [self.calendarManager.calendarAppearance dayCircleColorSelected];
                    backgroundView.frame = CGRectMake(0, (cellHeight - circleEdgeSize)/2, cellWidth/2, circleEdgeSize);
                    didChange = true;
                }
            } else if (self.calendarManager.endDate != nil && [self date:self.date isBetweenDate:self.calendarManager.startDate andDate:self.calendarManager.endDate]) {
                if (backgroundView.backgroundColor != [UIColor lightGrayColor] ||
                    isJustCreated) {
                    backgroundView.backgroundColor = [UIColor lightGrayColor];
                    backgroundView.frame = CGRectMake(0, (cellHeight - circleEdgeSize)/2, cellWidth, circleEdgeSize);
                    didChange = true;
                }
            } else {
                backgroundView.backgroundColor = [UIColor clearColor];
            }
            
            if (didChange) {
                backgroundView.alpha = 0;
                [UIView animateWithDuration:.3 animations:^{
                    backgroundView.alpha = 1;
                    circleView.transform = tr;
                }];
            }
        } else {
            backgroundView.backgroundColor = [UIColor clearColor];
        }

        circleView.layer.opacity = opacity;
    
    isJustCreated = false;
//    }
}

- (void)setIsOtherMonth:(BOOL)isOtherMonth
{
    self->_isOtherMonth = isOtherMonth;
    [self setSelected:isSelected animated:NO];
}

- (void)reloadData
{
    dotView.hidden = ![self.calendarManager.dataSource calendarHaveEvent:self.calendarManager date:self.date];
    
    if ([self isDateInTheFuture:self.date]) {
        if ([self isSameDate:self.calendarManager.startDate]) {
            [self setSelected:YES animated:YES];
        } else if ([self isSameDate:self.calendarManager.endDate]) {
            [self setSelected:YES animated:YES];
        } else {
            [self setSelected:NO animated:YES];
        }
    }
}

- (BOOL)isToday
{
    if(cacheIsToday == 0){
        return NO;
    }
    else if(cacheIsToday == 1){
        return YES;
    }
    else{
        if([self isSameDate:[NSDate date]]){
            cacheIsToday = 1;
            return YES;
        }
        else{
            cacheIsToday = 0;
            return NO;
        }
    }
}

- (BOOL)isSameDate:(NSDate *)date
{
    static NSDateFormatter *dateFormatter;
    if(!dateFormatter){
        dateFormatter = [NSDateFormatter new];
        dateFormatter.timeZone = self.calendarManager.calendarAppearance.calendar.timeZone;
        [dateFormatter setDateFormat:@"dd-MM-yyyy"];
    }
    
    if(!cacheCurrentDateText){
        cacheCurrentDateText = [dateFormatter stringFromDate:self.date];
    }
    
    NSString *dateText2 = [dateFormatter stringFromDate:date];
    
    if ([cacheCurrentDateText isEqualToString:dateText2]) {
        return YES;
    }
    
    return NO;
}

- (BOOL)date:(NSDate *)date isBetweenDate:(NSDate *)beginDate andDate:(NSDate *)endDate
{
    if ([date compare:beginDate] == NSOrderedAscending)
        return NO;
    
    if ([date compare:endDate] == NSOrderedDescending)
        return NO;
    
    return YES;
}

- (NSInteger)monthIndexForDate:(NSDate *)date
{
    NSCalendar *calendar = self.calendarManager.calendarAppearance.calendar;
    NSDateComponents *comps = [calendar components:NSCalendarUnitMonth fromDate:date];
    return comps.month;
}

- (void)reloadAppearance
{
    textLabel.textAlignment = NSTextAlignmentCenter;
    textLabel.font = self.calendarManager.calendarAppearance.dayTextFont;

    monthLabel.textAlignment = NSTextAlignmentCenter;
    monthLabel.font = self.calendarManager.calendarAppearance.menuMonthTextFont;

    yearLabel.textAlignment = NSTextAlignmentCenter;
    yearLabel.font = self.calendarManager.calendarAppearance.menuYearTextFont;

    [self configureConstraintsForSubviews];
    
    if ([self isDateInTheFuture:self.date]) {
        if ([self isSameDate:self.calendarManager.startDate]) {
            [self setSelected:YES animated:YES];
        } else if ([self isSameDate:self.calendarManager.endDate]) {
            [self setSelected:YES animated:YES];
        } else {
            [self setSelected:NO animated:YES];
        }
    }
}

@end
