## 개요
modelMapper 를 사용해 dto 를 변환할 때, modelMapper 가 내가 예상한대로 동작하지 않은 적이 종종 있어서 정확히 어떤 기준을 가지고 매핑을 수행하는지 알아보려고 함.

## 연구에 사용될 예제코드
문제가 되는 상황은 아래와 같이 여러 DTO 가 중첩되어 있는 상황에서, 최상위 DTO 에 대해 `mapper.map()` 을 수행하는 상황이다.
```
Order → OrderDto
  └─ Customer → CustomerDto  
       └─ Address → AddressDto
```

먼저 DTO 로 변환되기 전의 엔티티는 아래와 같다. (getter, setter, @Id, @Entity 등은 생략함)

### Order
```java
public class Order {
    private Long id;
    private Customer customer;
    private BigDecimal totalAmount;
    private LocalDateTime orderDate;
}
```

### Customer
```java
public class Customer {
    private Long id;
    private String name;
    private Address address;
    private CustomerType type;  // enum 타입임에 주목
}

public enum CustomerType {
    REGULAR, PREMIUM, VIP
}
```

### Address
```java
public class Address {
    private String city;
    private String street;
    private String zipCode;
}
```

그리고 위의 엔티티들이 변환될 DTO 는 아래와 같다. 주목할 점은, 엔티티에 존재하지 않는 필드가 있기도 하고 동일한 필드지만 타입이 다른 필드도 존재한다는 점이다.

### OrderDto
```java
public class OrderDto {
    private Long id;
    private CustomerDto customer;
    private String formattedAmount;  // BigDecimal 대신 String 타입임에 주목
}
```

### CustomerDto
```java
public class CustomerDto {
    private Long id;
    private String displayName;  // 엔티티의 name 대신 다른 필드명을 사용함에 주목
    private AddressDto address;
    private String customerLevel;  // enum 대신 String 타입임에 주목
}
```

### AddressDto
```java
public class AddressDto {
    private String city;
    private String fullAddress;  // street와 zipCode를 합친 필드임에 주목
}
```

이렇게 엔티티와 1:1 로 매핑되지 않는 필드들을 매핑해 주기 위해 아래와 같은 configuration 설정이 필요하다.

### ModelMapperConfig
```java
@Configuration
public class ModelMapperConfig {
    
    @Bean
    public ModelMapper modelMapper() {
        ModelMapper modelMapper = new ModelMapper();
        modelMapper.getConfiguration().setAmbiguityIgnored(true);

        // 1. Order -> OrderDto 매핑 설정
        TypeMap<Order, OrderDto> orderTypeMap = 
            modelMapper.createTypeMap(Order.class, OrderDto.class);
        
        orderTypeMap.addMappings(mapper -> {
            // 금액 포맷팅
            mapper.using(ctx -> {
                BigDecimal amount = (BigDecimal) ctx.getSource();
                return amount != null ? "$" + amount.toString() : null;
            }).map(Order::getTotalAmount, OrderDto::setFormattedAmount);
            
            // 중첩된 customer에 대한 '단순 매핑'
            mapper.map(Order::getCustomer, OrderDto::setCustomer);
        });

        // 2. Customer -> CustomerDto 매핑 설정
        TypeMap<Customer, CustomerDto> customerTypeMap = 
            modelMapper.createTypeMap(Customer.class, CustomerDto.class);
        
        customerTypeMap.addMappings(mapper -> {
            // name을 displayName으로 매핑
            mapper.map(Customer::getName, CustomerDto::setDisplayName);
            
            // enum을 string으로 변환
            mapper.using(ctx -> {
                CustomerType type = (CustomerType) ctx.getSource();
                return type != null ? type.toString().toLowerCase() : null;
            }).map(Customer::getType, CustomerDto::setCustomerLevel);
            
            // 중첩된 address에 대한 '단순 매핑'
            mapper.map(Customer::getAddress, CustomerDto::setAddress);
        });
        
        // 3. Address -> AddressDto 매핑 설정
        TypeMap<Address, AddressDto> addressTypeMap = 
            modelMapper.createTypeMap(Address.class, AddressDto.class);
        
        addressTypeMap.addMappings(mapper -> {
            // street와 zipCode를 fullAddress로 합치기
            mapper.using(ctx -> {
                Address source = (Address) ctx.getSource();
                return source.getStreet() + ", " + source.getZipCode();
            }).map(src -> src, AddressDto::setFullAddress);
        });
        
        return modelMapper;
    }
}
```

이제 이를 사용하는 매우 간단한 서비스 코드를 작성해보자

### OrderService (버전 1)
```java
@Service
@RequiredArgsConstructor
public class OrderService {
    
    private final ModelMapper modelMapper;
    
    public OrderDto getOrder(Order order) {
        return modelMapper.map(order, OrderDto.class);
    }
}
```

위 메서드의 결과는 어떻게 나올까? 결과는 아래와 같다.

```json
{
  "id": 1,
  "formattedAmount": "$100.50",
  "customer": {
    "id": 1,
    "displayName": null,
    "customerLevel": null,
    "address": {
      "city": "Seoul",
      "fullAddress": null
    }
  }
}
```

## 문제와 원인

### 문제

아닛?! `customer.displayName`, `customer.customerLevel`, `customer.address.fullAddress` 가 모두 null 이다. 이 필드들의 공통점은 modelMapper 의 기본 동작인 필드 매핑을 사용하지 않고, 위의 설정에서 커스텀하게 매핑을 지정해준 필드들이라는 것이다.

### 원인

이러한 문제가 발생하는 이유는, OrderDto 의 매퍼 설정에서 `mapper.map(Order::getCustomer, OrderDto::setCustomer);` 와 같이 설정하면 CustomerDto 에 대해 등록된 커스텀 TypeMap 을 사용하지 않고 단순 필드 기반의 매핑만 적용되도록 modelMapper 가 구현되어 있기 때문이다. 즉, 기존 엔티티에는 존재하지 않았거나 타입이 다른 `displayName`, `customerLevel` 필드가 생성되지 못하는 것이다. (customer -> address 에서도 동일한 문제가 발생한다.)

더 정확하게는, 

## 해결 방법